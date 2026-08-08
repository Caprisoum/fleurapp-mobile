import 'package:flutter/foundation.dart';

import '../models/upcoming_alert.dart';
import '../services/fleur_api_client.dart';
import '../services/local_alert_scheduler.dart';

enum UpcomingAlertsStatus { initial, loading, ready, error }

class UpcomingAlertsController extends ChangeNotifier {
  UpcomingAlertsController({
    required AdminApiClient apiClient,
    required LocalAlertScheduler scheduler,
  })  : _apiClient = apiClient,
        _scheduler = scheduler;

  final AdminApiClient _apiClient;
  final LocalAlertScheduler _scheduler;
  UpcomingAlertsPayload? payload;
  UpcomingAlertsStatus status = UpcomingAlertsStatus.initial;
  String? error;
  bool remindersEnabled = false;
  int scheduledCount = 0;
  int shownNowCount = 0;
  bool _disposed = false;

  List<UpcomingAlert> get alerts => payload?.alerts ?? const [];
  int get alertCount => alerts.length;

  Future<void> initialize() async {
    try {
      await _scheduler.initialize();
    } catch (_) {
      error =
          'Les notifications locales ne sont pas disponibles sur cet appareil.';
      _notify();
    }
  }

  Future<void> refresh({bool requestPermission = false}) async {
    status = UpcomingAlertsStatus.loading;
    error = null;
    _notify();
    try {
      final result = await _apiClient.fetchUpcomingAlerts();
      if (requestPermission) await _scheduler.requestPermission();
      final sync = await _scheduler.sync(result);
      payload = result;
      remindersEnabled = sync.enabled;
      scheduledCount = sync.scheduled;
      shownNowCount = sync.shownNow;
      status = UpcomingAlertsStatus.ready;
    } catch (exception) {
      status = UpcomingAlertsStatus.error;
      error = exception.toString();
      rethrow;
    } finally {
      _notify();
    }
  }

  Future<bool> enableReminders() async {
    final granted = await _scheduler.requestPermission();
    if (payload != null) {
      final sync = await _scheduler.sync(payload!);
      remindersEnabled = sync.enabled;
      scheduledCount = sync.scheduled;
      shownNowCount = sync.shownNow;
    } else {
      remindersEnabled = granted;
    }
    _notify();
    return remindersEnabled;
  }

  Future<void> reset() async {
    await _scheduler.clear();
    payload = null;
    status = UpcomingAlertsStatus.initial;
    error = null;
    remindersEnabled = false;
    scheduledCount = 0;
    shownNowCount = 0;
    _notify();
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
