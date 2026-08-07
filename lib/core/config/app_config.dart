class AppConfig {
  const AppConfig._();

  /// Injectée au lancement ou à la compilation :
  /// --dart-define=API_BASE_URL=https://votre-service.onrender.com
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
}
