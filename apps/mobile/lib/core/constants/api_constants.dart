class ApiConstants {
  // Configured via compile-time environment variable: --dart-define=API_BASE_URL=...
  // Default points to standard Android emulator loopback or localhost
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000/api/v1',
  );

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);

  // Auth endpoints
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';

  // Paper Trading & Portfolio endpoints
  static const String paperAccount = '/paper-account';
  static const String resetCapital = '/paper-account/reset';
  static const String portfolio = '/portfolio';
  static const String orders = '/portfolio/orders';
  static const String watchlists = '/watchlists';
}
