import 'package:flutter/material.dart';

import '../services/admin_token_store.dart';
import '../services/checkout_device_token_store.dart';
import '../services/api_exception.dart';
import '../services/device_metadata_service.dart';
import '../services/fleur_api_client.dart';
import '../services/local_settings_store.dart';
import '../services/local_alert_scheduler.dart';
import 'admin_controller.dart';
import 'pos_controller.dart';
import 'upcoming_alerts_controller.dart';
import '../models/bug_report.dart';

class AppController extends ChangeNotifier {
  AppController({
    required RenderApiClient apiClient,
    required LocalSettingsStore settingsStore,
    required AdminTokenStore tokenStore,
    CheckoutDeviceTokenStore? checkoutTokenStore,
    LocalAlertScheduler alertScheduler = const NoopLocalAlertScheduler(),
    DeviceMetadataService deviceMetadataService =
        const FallbackDeviceMetadataService(),
  })  : _apiClient = apiClient,
        _settingsStore = settingsStore,
        _tokenStore = tokenStore,
        _checkoutTokenStore =
            checkoutTokenStore ?? EphemeralCheckoutDeviceTokenStore(),
        _deviceMetadataService = deviceMetadataService,
        pos = PosController(apiClient: apiClient),
        admin = AdminController(apiClient: apiClient),
        upcomingAlerts = UpcomingAlertsController(
          apiClient: apiClient,
          scheduler: alertScheduler,
        );

  final RenderApiClient _apiClient;
  final LocalSettingsStore _settingsStore;
  final AdminTokenStore _tokenStore;
  final CheckoutDeviceTokenStore _checkoutTokenStore;
  final DeviceMetadataService _deviceMetadataService;
  final PosController pos;
  final AdminController admin;
  final UpcomingAlertsController upcomingAlerts;

  ThemeMode _themeMode = ThemeMode.system;
  bool _initialized = false;
  bool _adminAuthenticated = false;
  bool _authBusy = false;
  bool _checkoutDeviceBusy = false;
  bool _disposed = false;

  ThemeMode get themeMode => _themeMode;
  bool get initialized => _initialized;
  bool get adminAuthenticated => _adminAuthenticated;
  bool get authBusy => _authBusy;
  bool get checkoutDeviceBusy => _checkoutDeviceBusy;
  bool get checkoutDeviceActive => _apiClient.hasCheckoutToken;
  String get apiBaseUrl => _apiClient.baseUrl;

  Future<void> initialize({bool loadCatalog = true}) async {
    await upcomingAlerts.initialize();
    final settings = await _settingsStore.read();
    _themeMode = settings.themeMode;
    _apiClient.updateBaseUrl(settings.apiBaseUrl);
    final checkoutToken = await _checkoutTokenStore.read();
    if (checkoutToken != null && checkoutToken.isNotEmpty) {
      _apiClient.updateCheckoutToken(checkoutToken);
      if (settings.apiBaseUrl.isNotEmpty) {
        try {
          await _apiClient.checkCheckoutDevice();
        } on ApiException catch (error) {
          if (error.isUnauthorized) {
            await _checkoutTokenStore.delete();
            _apiClient.updateCheckoutToken(null);
          }
        } catch (_) {
          // Une panne réseau ne doit pas supprimer une activation valide.
        }
      }
    }
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
      try {
        await upcomingAlerts.refresh(requestPermission: true);
      } on ApiException catch (error) {
        if (error.isUnauthorized) {
          await logout();
          rethrow;
        }
      } catch (_) {
        // La connexion admin reste utilisable même si les rappels sont indisponibles.
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
      try {
        await upcomingAlerts.reset();
      } catch (_) {
        // La session doit être supprimée même si Android refuse une annulation locale.
      }
      _apiClient.updateAdminToken(null);
      _adminAuthenticated = false;
      admin.reset();
      _notify();
    }
  }

  Future<void> handleUnauthorized() async {
    if (_adminAuthenticated) await logout();
  }

  Future<void> refreshUpcomingAlerts({bool silent = true}) async {
    if (!_adminAuthenticated ||
        upcomingAlerts.status == UpcomingAlertsStatus.loading) {
      return;
    }
    try {
      await upcomingAlerts.refresh();
    } on ApiException catch (error) {
      if (error.isUnauthorized) await handleUnauthorized();
      if (!silent) rethrow;
    } catch (_) {
      if (!silent) rethrow;
    }
  }

  Future<void> updateApiBaseUrl(String value) async {
    final normalized = RenderApiClient.normalizeBaseUrl(value);
    if (_apiClient.hasCheckoutToken) {
      try {
        await _apiClient.revokeCheckoutDevice();
      } catch (_) {
        // L’ancien serveur peut être indisponible ; le jeton local est supprimé.
      }
      await _checkoutTokenStore.delete();
      _apiClient.updateCheckoutToken(null);
    }
    _apiClient.updateBaseUrl(normalized);
    await _settingsStore.writeApiBaseUrl(normalized);
    await logout();
    await pos.loadProducts();
    _notify();
  }

  Future<void> activateCheckoutDevice() async {
    if (!_adminAuthenticated) {
      throw const ApiException(
        'Connectez-vous comme administrateur avant d’activer cette caisse.',
        statusCode: 401,
      );
    }
    if (_checkoutDeviceBusy) return;
    _checkoutDeviceBusy = true;
    _notify();
    try {
      final metadata = await _deviceMetadataService.load();
      final rawName = '${metadata.model} · FleurApp ${metadata.appVersion}';
      final name = rawName.length <= 80 ? rawName : rawName.substring(0, 80);
      final token = await _apiClient.registerCheckoutDevice(name);
      await _checkoutTokenStore.write(token);
      _apiClient.updateCheckoutToken(token);
    } on ApiException catch (error) {
      if (error.isUnauthorized) await handleUnauthorized();
      rethrow;
    } finally {
      _checkoutDeviceBusy = false;
      _notify();
    }
  }

  Future<void> deactivateCheckoutDevice() async {
    if (!_apiClient.hasCheckoutToken || _checkoutDeviceBusy) return;
    _checkoutDeviceBusy = true;
    _notify();
    try {
      await _apiClient.revokeCheckoutDevice();
      await _checkoutTokenStore.delete();
      _apiClient.updateCheckoutToken(null);
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _checkoutTokenStore.delete();
        _apiClient.updateCheckoutToken(null);
        return;
      }
      rethrow;
    } finally {
      _checkoutDeviceBusy = false;
      _notify();
    }
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

  Future<BugReport> submitBugReport({
    required String title,
    required String description,
    required BugCategory category,
  }) async {
    final metadata = await _deviceMetadataService.load();
    return _apiClient.submitBugReport(BugReportDraft(
      title: title,
      description: description,
      category: category,
      device: metadata,
    ));
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
    upcomingAlerts.dispose();
    _apiClient.close();
    super.dispose();
  }
}
