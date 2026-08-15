class AppConfig {
  const AppConfig._();

  /// L'origine publique stable est embarquée par défaut. Une autre origine ne
  /// doit être injectée que dans un build de recette contrôlé.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.fleurapp.fr',
  );

  /// Le choix manuel du serveur est volontairement absent des versions
  /// publiques. Il reste disponible pour les tunnels et backends QA avec :
  /// --dart-define=ALLOW_SERVER_CONFIGURATION=true
  static const bool allowServerConfiguration = bool.fromEnvironment(
    'ALLOW_SERVER_CONFIGURATION',
    defaultValue: false,
  );
}
