import 'package:flutter_test/flutter_test.dart';
import 'package:fleurapp_mobile/models/upcoming_alert.dart';
import 'package:fleurapp_mobile/services/fleur_api_client.dart';
import 'package:fleurapp_mobile/services/local_alert_scheduler.dart';
import 'package:fleurapp_mobile/state/upcoming_alerts_controller.dart';

void main() {
  test('charge le centre et synchronise les rappels locaux', () async {
    final scheduler = _FakeScheduler();
    final controller = UpcomingAlertsController(
      apiClient: _FakeAdminApi(),
      scheduler: scheduler,
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    await controller.refresh(requestPermission: true);

    expect(controller.status, UpcomingAlertsStatus.ready);
    expect(controller.alerts.single.type, UpcomingAlertType.order);
    expect(controller.imminentAlerts, hasLength(1));
    expect(controller.arrivalAlerts, isEmpty);
    expect(controller.alertCount, 1);
    expect(controller.remindersEnabled, isTrue);
    expect(controller.scheduledCount, 1);
    expect(scheduler.permissionRequests, 1);
    expect(scheduler.syncedPayloads, 1);

    await controller.reset();
    expect(controller.status, UpcomingAlertsStatus.initial);
    expect(scheduler.cleared, isTrue);
  });
}

class _FakeAdminApi implements AdminApiClient {
  @override
  Future<UpcomingAlertsPayload> fetchUpcomingAlerts() async =>
      UpcomingAlertsPayload.fromJson({
        'generatedAt': '2026-08-08T08:00:00.000Z',
        'window': {
          'to': '2026-08-10T08:00:00.000Z',
          'timeZone': 'Europe/Paris',
        },
        'summary': {
          'total': 1,
          'arrivals': 0,
          'orders': 1,
          'bomAlerts': 0,
          'critical': 0,
        },
        'notifications': [
          {
            'id': 'order:42:2026-08-09T10:00:00.000Z',
            'type': 'order',
            'severity': 'warning',
            'title': 'Commande #42 à préparer',
            'message': 'Livraison demain.',
            'eventAt': '2026-08-09T10:00:00.000Z',
            'remindAt': '2026-08-08T10:00:00.000Z',
            'hoursUntil': 26,
            'data': {'orderId': 42},
          }
        ],
      });

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeScheduler implements LocalAlertScheduler {
  int permissionRequests = 0;
  int syncedPayloads = 0;
  bool cleared = false;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async {
    permissionRequests += 1;
    return true;
  }

  @override
  Future<LocalAlertSyncResult> sync(UpcomingAlertsPayload payload) async {
    syncedPayloads += 1;
    return const LocalAlertSyncResult(
      enabled: true,
      scheduled: 1,
      shownNow: 0,
    );
  }

  @override
  Future<void> clear() async => cleared = true;
}
