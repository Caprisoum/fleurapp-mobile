class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiConfigurationException extends ApiException {
  const ApiConfigurationException()
      : super(
          'Adresse du backend absente. Relancez avec '
          '--dart-define=API_BASE_URL=https://votre-service.onrender.com',
        );
}
