import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _storage = FlutterSecureStorage();
const _tokenKey = 'twain_auth_token';

Future<void> saveAuthToken(String token) =>
    _storage.write(key: _tokenKey, value: token);
Future<String?> readAuthToken() => _storage.read(key: _tokenKey);
Future<void> clearAuthToken() => _storage.delete(key: _tokenKey);

class TwainApiClient {
  TwainApiClient(this._dio);

  final Dio _dio;

  Dio get dio => _dio;

  static TwainApiClient create(String baseUrl) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 60),
        contentType: 'application/json',
        validateStatus: (code) => code != null && code < 500,
      ),
    );
    dio.interceptors.add(_AuthInterceptor());
    return TwainApiClient(dio);
  }
}

class _AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await readAuthToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

/// Override in each app's ProviderScope with the concrete base URL.
final apiClientProvider = Provider<TwainApiClient>(
  (ref) => throw UnimplementedError(
    'apiClientProvider must be overridden in app main()',
  ),
);
