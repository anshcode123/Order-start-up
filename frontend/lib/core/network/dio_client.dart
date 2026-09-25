import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scanserve/core/network/token_storage.dart';

/// Base URL for the ScanServe API.
/// Configurable at build time via:
/// flutter build web --dart-define=API_BASE_URL=https://api.yourdomain.com/api
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://order-start-up.onrender.com/api',
);

/// Overridden in main.dart once SharedPreferences has loaded, since
/// that load is async and providers are constructed synchronously.
final tokenStorageProvider = Provider<TokenStorage>((ref) {
  throw UnimplementedError(
      'tokenStorageProvider must be overridden in main.dart');
});

/// Riverpod provider exposing a configured [Dio] instance for the whole app.
/// Every request automatically carries the stored JWT (if any) as a
/// Bearer token - individual API calls never need to attach it themselves.
final dioProvider = Provider<Dio>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: kApiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = tokenStorage.token;
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (DioException error, handler) async {
        // If a stored JWT expired or was invalidated mid-session (excluding login attempts),
        // clear the stale token from storage so subsequent checks know it's invalid.
        if (error.response?.statusCode == 401 &&
            !error.requestOptions.path.contains('/auth/login')) {
          await tokenStorage.clear();
        }
        handler.next(error);
      },
    ),
  );

  return dio;
});
