import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/money.dart';
import '../models/admin_models.dart';
import '../models/bug_report.dart';
import '../models/bom_recipe.dart';
import '../models/cart_item.dart';
import '../models/catalog_import.dart';
import '../models/order_receipt.dart';
import '../models/order_history.dart';
import '../models/payment_method.dart';
import '../models/product.dart';
import '../models/upcoming_alert.dart';
import 'api_exception.dart';

abstract class FleurApiClient {
  Future<void> checkHealth();
  Future<List<Product>> fetchProducts();
  Future<List<ProductCategory>> fetchCategories();
  Future<BugReport> submitBugReport(BugReportDraft report);
  Future<OrderReceipt> createOrder({
    required List<CartItem> items,
    required PaymentMethod paymentMethod,
    required String idempotencyKey,
    int? customerId,
    bool isFutureOrder = false,
    DateTime? deliveryDate,
    int? depositCents,
  });
  void close();
}

abstract class AdminApiClient {
  Future<AdminLoginResult> login(String pin);
  Future<List<Product>> fetchProducts();
  Future<List<ProductCategory>> fetchCategories();
  Future<List<Customer>> fetchCustomers();
  Future<Customer> createCustomer(CustomerDraft customer);
  Future<List<OrderSummary>> fetchOrders();
  Future<OrderDetail> fetchOrderDetail(int id);
  Future<CancellationReceipt> cancelOrder({
    required int orderId,
    required String reason,
    required String idempotencyKey,
  });
  Future<List<BomRecipe>> fetchBomRecipes();
  Future<BomRecipe> saveBomRecipe(BomRecipeDraft recipe);
  Future<void> deleteBomRecipe(int parentId);
  Future<void> createCategory(String name);
  Future<void> deleteCategory(int id);
  Future<void> createProduct(ProductDraft product);
  Future<void> updateProduct(int id, ProductDraft product);
  Future<void> deleteProduct(int id);
  Future<CatalogImportPreview> previewCatalogImport(
    List<CatalogImportRow> rows,
    CatalogDuplicateMode duplicateMode,
  );
  Future<CatalogImportResult> importCatalog(
    List<CatalogImportRow> rows,
    CatalogDuplicateMode duplicateMode,
    String idempotencyKey,
  );
  Future<Product> applyAntiWasteDiscount(int productId, {int percentage = 30});
  Future<List<StockReception>> fetchStockReceptions();
  Future<void> receiveStock(Product product, int quantity);
  Future<List<WasteRecord>> fetchWasteRecords();
  Future<void> declareWaste(Product product, int quantity, String reason);
  Future<List<ClosureRecord>> fetchClosures();
  Future<ClosureReceipt> closeDay();
  Future<String> exportFec(int year);
  Future<UpcomingAlertsPayload> fetchUpcomingAlerts();
  Future<List<BugReport>> fetchBugReports({BugReportStatus? status});
  Future<BugReport> updateBugReportStatus(
    int id,
    BugReportStatus status,
  );
}

class RenderApiClient implements FleurApiClient, AdminApiClient {
  RenderApiClient({
    required String baseUrl,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 25),
  })  : _baseUrl = normalizeBaseUrl(baseUrl),
        _httpClient = httpClient ?? http.Client();

  String _baseUrl;
  String? _adminToken;
  String? _checkoutToken;
  final http.Client _httpClient;
  final Duration timeout;

  String get baseUrl => _baseUrl;
  bool get hasAdminToken => _adminToken?.isNotEmpty == true;
  bool get hasCheckoutToken => _checkoutToken?.isNotEmpty == true;

  void updateBaseUrl(String value) => _baseUrl = normalizeBaseUrl(value);
  void updateAdminToken(String? value) => _adminToken = value;
  void updateCheckoutToken(String? value) => _checkoutToken = value;

  Future<String> registerCheckoutDevice(String name) async {
    final payload = await _sendJson(
      'POST',
      '/api/admin/devices',
      body: {'nom': name},
      admin: true,
      acceptedStatusCodes: const {201},
    );
    final token = payload['token']?.toString();
    if (token == null || !RegExp(r'^fdev_[A-Za-z0-9_-]{43}$').hasMatch(token)) {
      throw const ApiException('Jeton d’activation de caisse invalide.');
    }
    return token;
  }

  Future<void> checkCheckoutDevice() =>
      _sendVoid('GET', '/api/devices/me', checkout: true);

  Future<void> revokeCheckoutDevice() =>
      _sendVoid('DELETE', '/api/devices/me', checkout: true);

  @override
  Future<void> checkHealth() async {
    await _request(() => _httpClient.get(_uri('/api/health')));
  }

  @override
  Future<AdminLoginResult> login(String pin) async {
    final payload = await _sendJson(
      'POST',
      '/api/auth/login',
      body: {'pin': pin},
    );
    final token = payload['token']?.toString();
    if (token == null || token.isEmpty) {
      throw const ApiException('Jeton administrateur absent de la réponse.');
    }
    return AdminLoginResult(
      token: token,
      expiresIn: '${payload['expiresIn'] ?? ''}',
    );
  }

  @override
  Future<List<Product>> fetchProducts() =>
      _getList('/api/produits', Product.fromJson);

  @override
  Future<List<ProductCategory>> fetchCategories() =>
      _getList('/api/categories', ProductCategory.fromJson);

  @override
  Future<BugReport> submitBugReport(BugReportDraft report) async {
    final payload = await _sendJson(
      'POST',
      '/api/bugs',
      body: report.toJson(),
      acceptedStatusCodes: const {201},
    );
    final bug = payload['bug'];
    if (bug is! Map) {
      throw const ApiException('Rapport créé absent de la réponse.');
    }
    try {
      return BugReport.fromJson(Map<String, dynamic>.from(bug));
    } on FormatException catch (error) {
      throw ApiException(error.message);
    }
  }

  @override
  Future<List<Customer>> fetchCustomers() =>
      _getList('/api/clients', Customer.fromJson, admin: true);

  @override
  Future<Customer> createCustomer(CustomerDraft customer) async {
    final payload = await _sendJson(
      'POST',
      '/api/clients',
      body: customer.toJson(),
      admin: true,
      acceptedStatusCodes: const {201},
    );
    final created = payload['client'];
    if (created is! Map) {
      throw const ApiException('Client créé absent de la réponse.');
    }
    return Customer.fromJson(Map<String, dynamic>.from(created));
  }

  @override
  Future<List<OrderSummary>> fetchOrders() => _getList(
        '/api/commandes?limit=200',
        OrderSummary.fromJson,
        admin: true,
      );

  @override
  Future<OrderDetail> fetchOrderDetail(int id) async {
    final payload = await _sendJson(
      'GET',
      '/api/commandes/$id',
      admin: true,
    );
    try {
      return OrderDetail.fromJson(payload);
    } on FormatException catch (error) {
      throw ApiException(error.message);
    }
  }

  @override
  Future<CancellationReceipt> cancelOrder({
    required int orderId,
    required String reason,
    required String idempotencyKey,
  }) async {
    final payload = await _sendJson(
      'POST',
      '/api/commandes/$orderId/annulations',
      body: {'motif': reason},
      admin: true,
      extraHeaders: {'Idempotency-Key': idempotencyKey},
      acceptedStatusCodes: const {200, 201},
      outcomeCouldBeUnknown: true,
      unknownOutcomeMessage:
          'Connexion interrompue : l’annulation a peut-être été enregistrée. Réessayez sans modifier le motif.',
    );
    try {
      return CancellationReceipt.fromJson(payload);
    } on FormatException catch (error) {
      throw ApiException(error.message);
    }
  }

  @override
  Future<List<BomRecipe>> fetchBomRecipes() =>
      _getList('/api/bom', BomRecipe.fromJson, admin: true);

  @override
  Future<BomRecipe> saveBomRecipe(BomRecipeDraft recipe) async {
    final payload = await _sendJson(
      'PUT',
      '/api/bom/${recipe.parentId}',
      body: recipe.toJson(),
      admin: true,
    );
    final saved = payload['recipe'];
    if (saved is! Map) {
      throw const ApiException('Nomenclature absente de la réponse.');
    }
    try {
      return BomRecipe.fromJson(Map<String, dynamic>.from(saved));
    } on FormatException catch (error) {
      throw ApiException(error.message);
    }
  }

  @override
  Future<void> deleteBomRecipe(int parentId) =>
      _sendVoid('DELETE', '/api/bom/$parentId', admin: true);

  @override
  Future<List<StockReception>> fetchStockReceptions() => _getList(
        '/api/stock/receptions?limit=50',
        StockReception.fromJson,
        admin: true,
      );

  @override
  Future<List<WasteRecord>> fetchWasteRecords() =>
      _getList('/api/pertes', WasteRecord.fromJson, admin: true);

  @override
  Future<List<ClosureRecord>> fetchClosures() =>
      _getList('/api/clotures', ClosureRecord.fromJson, admin: true);

  @override
  Future<UpcomingAlertsPayload> fetchUpcomingAlerts() async {
    final payload = await _sendJson(
      'GET',
      '/api/notifications/a-venir?days=42',
      admin: true,
    );
    try {
      return UpcomingAlertsPayload.fromJson(payload);
    } on FormatException catch (error) {
      throw ApiException(error.message);
    }
  }

  @override
  Future<List<BugReport>> fetchBugReports({BugReportStatus? status}) {
    final query = <String, String>{'limit': '200'};
    if (status != null) query['statut'] = status.apiValue;
    final path =
        Uri(path: '/api/admin/bugs', queryParameters: query).toString();
    return _getList(path, BugReport.fromJson, admin: true);
  }

  @override
  Future<BugReport> updateBugReportStatus(
    int id,
    BugReportStatus status,
  ) async {
    final payload = await _sendJson(
      'PATCH',
      '/api/admin/bugs/$id',
      body: {'statut': status.apiValue},
      admin: true,
    );
    final bug = payload['bug'];
    if (bug is! Map) {
      throw const ApiException('Rapport actualisé absent de la réponse.');
    }
    try {
      return BugReport.fromJson(Map<String, dynamic>.from(bug));
    } on FormatException catch (error) {
      throw ApiException(error.message);
    }
  }

  @override
  Future<OrderReceipt> createOrder({
    required List<CartItem> items,
    required PaymentMethod paymentMethod,
    required String idempotencyKey,
    int? customerId,
    bool isFutureOrder = false,
    DateTime? deliveryDate,
    int? depositCents,
  }) async {
    final body = <String, dynamic>{
      'cartItems': items.map((item) => item.toApiJson()).toList(),
      'mode_paiement': paymentMethod.apiValue,
      'isFutureOrder': isFutureOrder,
    };
    if (customerId != null) body['clientId'] = customerId;
    if (deliveryDate != null) {
      body['deliveryDate'] = deliveryDate.toUtc().toIso8601String();
    }
    if (depositCents != null) {
      body['acompte'] = centsToApiDecimal(depositCents);
    }
    final payload = await _sendJson(
      'POST',
      '/api/commandes',
      body: body,
      extraHeaders: {'Idempotency-Key': idempotencyKey},
      checkout: true,
      acceptedStatusCodes: const {200, 201},
      outcomeCouldBeUnknown: true,
    );
    try {
      return OrderReceipt.fromJson(payload);
    } on FormatException catch (error) {
      throw ApiException(error.message);
    }
  }

  @override
  Future<void> createCategory(String name) => _sendVoid(
        'POST',
        '/api/categories',
        body: {'nom': name},
        admin: true,
        acceptedStatusCodes: const {200, 201},
      );

  @override
  Future<void> deleteCategory(int id) =>
      _sendVoid('DELETE', '/api/categories/$id', admin: true);

  @override
  Future<void> createProduct(ProductDraft product) => _sendVoid(
        'POST',
        '/api/produits',
        body: product.toJson(),
        admin: true,
        acceptedStatusCodes: const {200, 201},
      );

  @override
  Future<void> updateProduct(int id, ProductDraft product) => _sendVoid(
        'PUT',
        '/api/produits/$id',
        body: product.toJson(),
        admin: true,
      );

  @override
  Future<void> deleteProduct(int id) =>
      _sendVoid('DELETE', '/api/produits/$id', admin: true);

  @override
  Future<CatalogImportPreview> previewCatalogImport(
    List<CatalogImportRow> rows,
    CatalogDuplicateMode duplicateMode,
  ) async {
    final payload = await _sendJson(
      'POST',
      '/api/admin/catalogue/import/preview',
      body: {
        'rows': rows.map((row) => row.toJson()).toList(growable: false),
        'duplicate_mode': duplicateMode.apiValue,
      },
      admin: true,
    );
    return CatalogImportPreview.fromJson(payload);
  }

  @override
  Future<CatalogImportResult> importCatalog(
    List<CatalogImportRow> rows,
    CatalogDuplicateMode duplicateMode,
    String idempotencyKey,
  ) async {
    final payload = await _sendJson(
      'POST',
      '/api/admin/catalogue/import',
      body: {
        'rows': rows.map((row) => row.toJson()).toList(growable: false),
        'duplicate_mode': duplicateMode.apiValue,
      },
      admin: true,
      extraHeaders: {'Idempotency-Key': idempotencyKey},
      acceptedStatusCodes: const {201},
    );
    return CatalogImportResult.fromJson(payload);
  }

  @override
  Future<Product> applyAntiWasteDiscount(
    int productId, {
    int percentage = 30,
  }) async {
    final payload = await _sendJson(
      'POST',
      '/api/produits/$productId/remise-anti-gaspi',
      body: {'pourcentage': percentage},
      admin: true,
    );
    final product = payload['product'];
    if (product is! Map) {
      throw const ApiException('Produit actualisé absent de la réponse.');
    }
    return Product.fromJson(Map<String, dynamic>.from(product));
  }

  @override
  Future<void> receiveStock(Product product, int quantity) => _sendVoid(
        'POST',
        '/api/stock/reception',
        body: {
          'produit_id': product.id,
          'quantite_recue': quantity,
          'unite_achat': product.purchaseUnit,
        },
        admin: true,
        acceptedStatusCodes: const {200, 201},
      );

  @override
  Future<void> declareWaste(
    Product product,
    int quantity,
    String reason,
  ) =>
      _sendVoid(
        'POST',
        '/api/pertes',
        body: {'productId': product.id, 'quantity': quantity, 'reason': reason},
        admin: true,
      );

  @override
  Future<ClosureReceipt> closeDay() async {
    final payload = await _sendJson(
      'POST',
      '/api/cloture-jour',
      admin: true,
    );
    return ClosureReceipt.fromJson(payload);
  }

  @override
  Future<String> exportFec(int year) async {
    final response = await _request(
      () => _httpClient.get(
        _uri('/api/export/fec?annee=$year'),
        headers: _headers(admin: true),
      ),
    );
    return utf8.decode(response.bodyBytes);
  }

  Future<List<T>> _getList<T>(
    String path,
    T Function(Map<String, dynamic>) parse, {
    bool admin = false,
  }) async {
    final response = await _request(
      () => _httpClient.get(_uri(path), headers: _headers(admin: admin)),
    );
    final payload = _decodeJson(response);
    if (payload is! List) throw const ApiException('Liste API inattendue.');
    try {
      return payload
          .map((item) => parse(Map<String, dynamic>.from(item as Map)))
          .toList(growable: false);
    } on FormatException catch (error) {
      throw ApiException(error.message);
    } on TypeError {
      throw const ApiException('Une donnée reçue est illisible.');
    }
  }

  Future<void> _sendVoid(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool admin = false,
    bool checkout = false,
    Set<int> acceptedStatusCodes = const {200},
  }) async {
    await _sendJson(
      method,
      path,
      body: body,
      admin: admin,
      checkout: checkout,
      acceptedStatusCodes: acceptedStatusCodes,
    );
  }

  Future<Map<String, dynamic>> _sendJson(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool admin = false,
    bool checkout = false,
    Map<String, String> extraHeaders = const {},
    Set<int> acceptedStatusCodes = const {200},
    bool outcomeCouldBeUnknown = false,
    String? unknownOutcomeMessage,
  }) async {
    final request = http.Request(method, _uri(path))
      ..headers.addAll(_headers(admin: admin, checkout: checkout))
      ..headers.addAll(extraHeaders);
    if (body != null) request.body = jsonEncode(body);
    final response = await _request(
      () => _httpClient.send(request).then(http.Response.fromStream),
      acceptedStatusCodes: acceptedStatusCodes,
      outcomeCouldBeUnknown: outcomeCouldBeUnknown,
      unknownOutcomeMessage: unknownOutcomeMessage,
    );
    final payload = _decodeJson(response);
    if (payload is! Map) throw const ApiException('Réponse API inattendue.');
    return Map<String, dynamic>.from(payload);
  }

  Map<String, String> _headers({required bool admin, bool checkout = false}) {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json; charset=UTF-8',
      'Bypass-Tunnel-Reminder': 'FleurApp-Mobile',
    };
    if (admin) {
      final token = _adminToken;
      if (token == null || token.isEmpty) {
        throw const ApiException(
          'Connexion administrateur requise.',
          statusCode: 401,
        );
      }
      headers['Authorization'] = 'Bearer $token';
    }
    if (checkout) {
      final token = _checkoutToken;
      if (token != null && token.isNotEmpty) {
        headers['X-Checkout-Token'] = token;
      }
    }
    return headers;
  }

  Uri _uri(String path) {
    if (_baseUrl.isEmpty) throw const ApiConfigurationException();
    return Uri.parse('$_baseUrl$path');
  }

  Future<http.Response> _request(
    Future<http.Response> Function() send, {
    Set<int> acceptedStatusCodes = const {200},
    bool outcomeCouldBeUnknown = false,
    String? unknownOutcomeMessage,
  }) async {
    try {
      final response = await send().timeout(timeout);
      if (!acceptedStatusCodes.contains(response.statusCode)) {
        final details = _extractError(response);
        throw ApiException(
          details.message,
          statusCode: response.statusCode,
          requestId: details.requestId,
        );
      }
      return response;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException(
        unknownOutcomeMessage ??
            (outcomeCouldBeUnknown
                ? 'Réponse perdue : la vente a peut-être été enregistrée. '
                    'Réessayez sans modifier le panier.'
                : 'Le serveur met trop de temps à répondre. Réessayez dans un instant.'),
        outcomeUnknown: outcomeCouldBeUnknown,
      );
    } on http.ClientException catch (error) {
      throw ApiException(
        unknownOutcomeMessage ??
            (outcomeCouldBeUnknown
                ? 'Connexion interrompue : l’état de la vente est inconnu. '
                    'Réessayez sans modifier le panier.'
                : 'Connexion au serveur impossible : ${error.message}'),
        outcomeUnknown: outcomeCouldBeUnknown,
      );
    } on FormatException {
      throw const ApiException('Adresse du backend invalide.');
    } catch (_) {
      throw ApiException(
        unknownOutcomeMessage ??
            (outcomeCouldBeUnknown
                ? 'Connexion interrompue : l’état de la vente est inconnu.'
                : 'Connexion au serveur impossible.'),
        outcomeUnknown: outcomeCouldBeUnknown,
      );
    }
  }

  dynamic _decodeJson(http.Response response) {
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const ApiException('Le serveur a renvoyé une réponse illisible.');
    }
  }

  _ErrorDetails _extractError(http.Response response) {
    try {
      final payload = jsonDecode(utf8.decode(response.bodyBytes));
      if (payload is Map && payload['error'] != null) {
        return _ErrorDetails(
          payload['error'].toString(),
          payload['requestId']?.toString(),
        );
      }
    } on FormatException {
      // Un corps HTML ou vide est remplacé par un message stable.
    }
    return _ErrorDetails('Erreur serveur (${response.statusCode}).', null);
  }

  @override
  void close() => _httpClient.close();

  static String normalizeBaseUrl(String value) {
    final normalized = value.trim().replaceFirst(RegExp(r'/+$'), '');
    if (normalized.isEmpty) return '';
    final uri = Uri.tryParse(normalized);
    final localDevelopment = uri?.scheme == 'http' &&
        const {'localhost', '127.0.0.1', '10.0.2.2'}.contains(uri?.host);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.scheme != 'https' && !localDevelopment) ||
        uri.path.isNotEmpty && uri.path != '/') {
      throw const ApiException(
        'Utilisez une URL HTTPS sans /api, par exemple https://service.onrender.com.',
      );
    }
    return normalized;
  }
}

class _ErrorDetails {
  const _ErrorDetails(this.message, this.requestId);
  final String message;
  final String? requestId;
}
