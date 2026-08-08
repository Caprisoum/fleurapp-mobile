import 'package:flutter/material.dart';

import '../services/admin_token_store.dart';
import '../services/api_exception.dart';
import '../services/fleur_api_client.dart';
import '../services/local_settings_store.dart';
import 'admin_controller.dart';
import 'pos_controller.dart';

class AppController extends ChangeNotifier {
  AppController({
    required RenderApiClient apiClient,
    required LocalSettingsStore settingsStore,
    required AdminTokenStore tokenStore,
  })  : _apiClient = apiClient,
        _settingsStore = settingsStore,
        _tokenStore = tokenStore,
        pos = PosController(apiClient: apiClient),
        admin = AdminController(apiClient: apiClient);

  final RenderApiClient _apiClient;
  final LocalSettingsStore _settingsStore;
  final AdminTokenStore _tokenStore;
  final PosController pos;
  final AdminController admin;

  ThemeMode _themeMode = ThemeMode.system;
  bool _initialized = false;
  bool _adminAuthenticated = false;
  bool _authBusy = false;
  bool _disposed = false;

  ThemeMode get themeMode => _themeMode;
  bool get initialized => _initialized;
  bool get adminAuthenticated => _adminAuthenticated;
  bool get authBusy => _authBusy;
  String get apiBaseUrl => _apiClient.baseUrl;

  Future<void> initialize({bool loadCatalog = true}) async {
    final settings = await _settingsStore.read();
    _themeMode = settings.themeMode;
    _apiClient.updateBaseUrl(settings.apiBaseUrl);
    final token = await _tokenStore.read();
    if (token != null && token.isNotEmpty) {
      _apiClient.updateAdminToken(token);
      _adminAuthenticated = true;
    }
    _initialized = true;
    _notify();
    if (loadCatalog) await pos.loadProducts();
  }

  Future<void> login(String pin) async {
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      throw const ApiException(
          'Le code PIN doit contenir exactement 4 chiffres.');
    }
    _authBusy = true;
    _notify();
    try {
      final result = await _apiClient.login(pin);
      await _tokenStore.write(result.token);
      _apiClient.updateAdminToken(result.token);
      _adminAuthenticated = true;
      try {
        await admin.loadAll();
      } on ApiException catch (error) {
        if (error.isUnauthorized) {
          await logout();
        }
        rethrow;
      }
    } finally {
      _authBusy = false;
      _notify();
    }
  }

  Future<void> logout() async {
    try {
      await _tokenStore.delete();
    } finally {
      _apiClient.updateAdminToken(null);
      _adminAuthenticated = false;
      admin.reset();
      _notify();
    }
  }

  Future<void> handleUnauthorized() async {
    if (_adminAuthenticated) await logout();
  }

  Future<void> updateApiBaseUrl(String value) async {
    final normalized = RenderApiClient.normalizeBaseUrl(value);
    _apiClient.updateBaseUrl(normalized);
    await _settingsStore.writeApiBaseUrl(normalized);
    await logout();
    await pos.loadProducts();
    _notify();
  }

  Future<void> checkHealth(String candidate) async {
    final previous = _apiClient.baseUrl;
    final normalized = RenderApiClient.normalizeBaseUrl(candidate);
    _apiClient.updateBaseUrl(normalized);
    try {
      await _apiClient.checkHealth();
    } finally {
      _apiClient.updateBaseUrl(previous);
    }
  }

  Future<void> setThemeMode(ThemeMode value) async {
    _themeMode = value;
    _notify();
    await _settingsStore.writeThemeMode(value);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    pos.dispose();
    admin.dispose();
    _apiClient.close();
    super.dispose();
  }
}
