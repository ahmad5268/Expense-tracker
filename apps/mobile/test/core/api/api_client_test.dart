import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:expense_tracker/core/api/api_client.dart';
import 'package:expense_tracker/core/auth/secure_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late SecureStorageService storage;
  late ApiClient client;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storage = SecureStorageService.withPrefs(prefs);

    dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'));
    adapter = DioAdapter(dio: dio);
    client = ApiClient.withDio(dio, storage);
  });

  group('JWT interceptor', () {
    test('attaches Authorization header when token is stored', () async {
      await storage.saveTokens(accessToken: 'test-token', refreshToken: 'rt');

      adapter.onGet(
        '/users/me',
        (server) => server.reply(200, {'data': {'id': '1'}}),
      );

      final response = await client.dio.get('/users/me');

      expect(response.statusCode, 200);
      expect(
        response.requestOptions.headers['Authorization'],
        'Bearer test-token',
      );
    });

    test('does not attach Authorization header when no token stored', () async {
      adapter.onGet(
        '/public',
        (server) => server.reply(200, {'data': 'ok'}),
      );

      final response = await client.dio.get('/public');

      expect(response.statusCode, 200);
      expect(response.requestOptions.headers['Authorization'], isNull);
    });

    test('on 401 with no refresh token: clears storage and propagates error',
        () async {
      // No tokens saved — refresh token is null → interceptor clears + throws
      adapter.onGet('/users/me',
          (server) => server.reply(401, {'message': 'Unauthorized'}));

      await expectLater(
        () => client.dio.get('/users/me'),
        throwsA(isA<DioException>()),
      );
      // Storage was already empty; still empty after the 401
      expect(await storage.getAccessToken(), isNull);
    });

    test('on 401 + failed refresh: clears tokens', () async {
      await storage.saveTokens(
          accessToken: 'expired-token', refreshToken: 'bad-refresh');

      adapter.onGet('/users/me',
          (server) => server.reply(401, {'message': 'Unauthorized'}));
      adapter.onPost('/auth/refresh',
          (server) => server.reply(401, {'message': 'Invalid refresh'}));

      await expectLater(
        () => client.dio.get('/users/me'),
        throwsA(isA<DioException>()),
      );
      expect(await storage.getAccessToken(), isNull);
      expect(await storage.getRefreshToken(), isNull);
    });
  });
}
