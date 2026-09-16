/// Central API configuration.
class ApiConstants {
  ApiConstants._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5000/api',
  );

  static const String login = '/auth/login';
  static const String me = '/auth/me';
}
