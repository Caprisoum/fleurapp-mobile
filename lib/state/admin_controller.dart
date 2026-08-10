import 'package:flutter/foundation.dart';

import '../models/admin_models.dart';
import '../models/bug_report.dart';
import '../models/catalog_import.dart';
import '../models/product.dart';
import '../services/api_exception.dart';
import '../services/fleur_api_client.dart';

enum AdminStatus { initial, loading, ready, error }

class AdminController extends ChangeNotifier {
  AdminController({required AdminApiClient apiClient}) : _apiClient = apiClient;

  final AdminApiClient _apiClient;
  List<Product> products = const [];
  List<ProductCategory> categories = const [];
  List<Customer> customers = const [];
  List<StockReception> receptions = const [];
  List<WasteRecord> wasteRecords = const [];
  List<ClosureRecord> closures = const [];
  List<BugReport> bugReports = const [];
  AdminStatus status = AdminStatus.initial;
  String? error;
  bool busy = false;
  bool _disposed = false;

  List<Product> get receptionProducts =>
      products.where((product) => product.hasUnitConversion).toList();

  Future<void> loadAll() async {
    status = AdminStatus.loading;
    error = null;
    _notify();
    try {
      final values = await Future.wait<Object>([
        _apiClient.fetchProducts(),
        _apiClient.fetchCategories(),
        _apiClient.fetchCustomers(),
        _apiClient.fetchStockReceptions(),
        _apiClient.fetchWasteRecords(),
        _apiClient.fetchClosures(),
        _apiClient.fetchBugReports(),
      ]);
      products = values[0] as List<Product>;
      categories = values[1] as List<ProductCategory>;
      customers = values[2] as List<Customer>;
      receptions = values[3] as List<StockReception>;
      wasteRecords = values[4] as List<WasteRecord>;
      closures = values[5] as List<ClosureRecord>;
      bugReports = values[6] as List<BugReport>;
      status = AdminStatus.ready;
    } on ApiException catch (exception) {
      status = AdminStatus.error;
      error = exception.message;
      rethrow;
    } catch (_) {
      status = AdminStatus.error;
      error = 'Impossible de charger l’espace de gestion.';
      rethrow;
    } finally {
      _notify();
    }
  }

  void reset() {
    products = const [];
    categories = const [];
    customers = const [];
    receptions = const [];
    wasteRecords = const [];
    closures = const [];
    bugReports = const [];
    status = AdminStatus.initial;
    error = null;
    busy = false;
    _notify();
  }

  Future<void> createCategory(String name) async {
    await _action(() => _apiClient.createCategory(name));
    await refreshCatalog();
  }

  Future<void> deleteCategory(int id) async {
    await _action(() => _apiClient.deleteCategory(id));
    await refreshCatalog();
  }

  Future<void> saveProduct(ProductDraft draft, {Product? existing}) async {
    await _action(() => existing == null
        ? _apiClient.createProduct(draft)
        : _apiClient.updateProduct(existing.id, draft));
    await refreshCatalog();
  }

  Future<void> deleteProduct(Product product) async {
    await _action(() => _apiClient.deleteProduct(product.id));
    await refreshCatalog();
  }

  Future<CatalogImportPreview> previewCatalogImport(
    List<CatalogImportRow> rows,
    CatalogDuplicateMode duplicateMode,
  ) =>
      _apiClient.previewCatalogImport(rows, duplicateMode);

  Future<CatalogImportResult> importCatalog(
    List<CatalogImportRow> rows,
    CatalogDuplicateMode duplicateMode,
    String idempotencyKey,
  ) async {
    late CatalogImportResult result;
    await _action(() async {
      result =
          await _apiClient.importCatalog(rows, duplicateMode, idempotencyKey);
    });
    await refreshCatalog();
    return result;
  }

  Future<void> applyAntiWaste(Product product) async {
    await _action(() => _apiClient.applyAntiWasteDiscount(product.id));
    await refreshCatalog();
  }

  Future<void> declareWaste(
    Product product,
    int quantity,
    String reason,
  ) async {
    await _action(() => _apiClient.declareWaste(product, quantity, reason));
    await Future.wait([refreshCatalog(), refreshActivity()]);
  }

  Future<void> receiveStock(Product product, int quantity) async {
    await _action(() => _apiClient.receiveStock(product, quantity));
    await Future.wait([refreshCatalog(), refreshStock()]);
  }

  Future<ClosureReceipt> closeDay() async {
    late ClosureReceipt receipt;
    await _action(() async => receipt = await _apiClient.closeDay());
    await refreshActivity();
    return receipt;
  }

  Future<String> exportFec(int year) => _apiClient.exportFec(year);

  Future<void> refreshCatalog() async {
    final values = await Future.wait<Object>([
      _apiClient.fetchProducts(),
      _apiClient.fetchCategories(),
    ]);
    products = values[0] as List<Product>;
    categories = values[1] as List<ProductCategory>;
    _notify();
  }

  Future<void> refreshStock() async {
    receptions = await _apiClient.fetchStockReceptions();
    _notify();
  }

  Future<void> refreshActivity() async {
    final values = await Future.wait<Object>([
      _apiClient.fetchWasteRecords(),
      _apiClient.fetchClosures(),
      _apiClient.fetchCustomers(),
    ]);
    wasteRecords = values[0] as List<WasteRecord>;
    closures = values[1] as List<ClosureRecord>;
    customers = values[2] as List<Customer>;
    _notify();
  }

  Future<void> refreshBugReports() async {
    bugReports = await _apiClient.fetchBugReports();
    _notify();
  }

  Future<void> updateBugReportStatus(
    BugReport report,
    BugReportStatus status,
  ) async {
    late BugReport updated;
    await _action(() async {
      updated = await _apiClient.updateBugReportStatus(report.id, status);
    });
    bugReports = bugReports
        .map((item) => item.id == updated.id ? updated : item)
        .toList(growable: false);
    _notify();
  }

  Future<void> _action(Future<void> Function() callback) async {
    busy = true;
    _notify();
    try {
      await callback();
    } finally {
      busy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
