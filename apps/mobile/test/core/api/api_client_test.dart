import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:expense_tracker/core/api/api_client.dart';
import 'package:expense_tracker/core/auth/secure_storage_service.dart';

@GenerateNiceMocks([MockSpec<SecureStorageService>()])
import 'api_client_test.mocks.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late MockSecureStorageService mockStorage;
  late ApiClient client;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'));
    adapter = DioAdapter(dio: dio);
    mockStorage = MockSecureStorageService();
    client = ApiClient.withDio(dio, mockStorage);
  });

  group('JWT interceptor', () {
    test('attaches Authorization header on every request', () async {
      when(mockStorage.getAccessToken()).thenAnswer((_) async => 'test-token');
      adapter.onGet(
        '/users/me',
        (server) => server.reply(200, {
          'data': {'id': '1'}
        }),
      );

      final response = await client.dio.get('/users/me');

      expect(response.statusCode, 200);
      expect(response.requestOptions.headers['Authorization'],
          'Bearer test-token');
    });

    test('on 401 refreshes token and retries original request', () async {
      when(mockStorage.getAccessToken())
          .thenAnswer((_) async => 'expired-token');
      when(mockStorage.getRefreshToken())
          .thenAnswer((_) async => 'refresh-token');
      when(mockStorage.saveTokens(
              accessToken: anyNamed('accessToken'),
              refreshToken: anyNamed('refreshToken')))
          .thenAnswer((_) async {});

      // First call to /users/me with expired token → 401
      adapter.onGet(
        '/users/me',
        (server) => server.reply(401, {'message': 'Unauthorized'}),
        headers: {'Authorization': 'Bearer expired-token'},
      );
      // Refresh call → new tokens
      adapter.onPost(
        '/auth/refresh',
        (server) => server.reply(200, {
          'data': {
            'accessToken': 'new-token',
            'refreshToken': 'new-refresh',
          }
        }),
      );
      // Retry /users/me with new token → 200
      adapter.onGet(
        '/users/me',
        (server) => server.reply(200, {
          'data': {'id': '1'}
        }),
        headers: {'Authorization': 'Bearer new-token'},
      );

      final response = await client.dio.get('/users/me');
      expect(response.statusCode, 200);
      verify(mockStorage.saveTokens(
              accessToken: 'new-token', refreshToken: 'new-refresh'))
          .called(1);
    });

    test('clears tokens when refresh fails', () async {
      when(mockStorage.getAccessToken())
          .thenAnswer((_) async => 'expired-token');
      when(mockStorage.getRefreshToken())
          .thenAnswer((_) async => 'bad-refresh');
      when(mockStorage.clearTokens()).thenAnswer((_) async {});

      adapter.onGet(
        '/users/me',
        (server) => server.reply(401, {'message': 'Unauthorized'}),
      );
      adapter.onPost(
        '/auth/refresh',
        (server) => server.reply(401, {'message': 'Invalid refresh'}),
      );

      expect(
        () => client.dio.get('/users/me'),
        throwsA(isA<DioException>()),
      );
    });
  });
}
