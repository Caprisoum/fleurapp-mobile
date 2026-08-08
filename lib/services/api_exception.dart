class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.requestId,
    this.outcomeUnknown = false,
  });

  final String message;
  final int? statusCode;
  final String? requestId;
  final bool outcomeUnknown;

  bool get isUnauthorized => statusCode == 401;
  bool get isConflict => statusCode == 409;

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
