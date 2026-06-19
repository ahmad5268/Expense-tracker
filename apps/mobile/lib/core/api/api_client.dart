import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/secure_storage_service.dart';

const _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:3000',
);

class ApiClient {
  final Dio dio;
  final SecureStorageService _storage;
  bool _isRefreshing = false;

  ApiClient._(this.dio, this._storage);

  factory ApiClient.withDio(Dio dio, SecureStorageService storage) {
    final client = ApiClient._(dio, storage);
    client._addInterceptors();
    return client;
  }

  static Future<ApiClient> create(SecureStorageService storage) async {
    final dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));
    return ApiClient.withDio(dio, storage);
  }

  void _addInterceptors() {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.getAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401 && !_isRefreshing) {
          _isRefreshing = true;
          var tokenRefreshed = false;
          try {
            final refreshToken = await _storage.getRefreshToken();
            if (refreshToken == null) throw Exception('No refresh token');

            // Use a separate Dio instance without the auth interceptor so
            // the refresh token is sent in Authorization instead of the
            // access token being injected by onRequest.
            final refreshDio = Dio(BaseOptions(
              baseUrl: _baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
              headers: {'Content-Type': 'application/json'},
            ));
            final response = await refreshDio.post(
              '/auth/refresh',
              options: Options(headers: {'Authorization': 'Bearer $refreshToken'}),
            );

            final newAccess = response.data['data']['accessToken'] as String;
            final newRefresh = response.data['data']['refreshToken'] as String;
            await _storage.saveTokens(
              accessToken: newAccess,
              refreshToken: newRefresh,
            );
            tokenRefreshed = true;

            final retryOptions = error.requestOptions;
            retryOptions.headers['Authorization'] = 'Bearer $newAccess';
            final retried = await dio.fetch(retryOptions);
            handler.resolve(retried);
          } catch (_) {
            if (!tokenRefreshed) await _storage.clearTokens();
            handler.next(error);
          } finally {
            _isRefreshing = false;
          }
        } else {
          handler.next(error);
        }
      },
    ));
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  throw UnimplementedError('Override in ProviderScope');
});
