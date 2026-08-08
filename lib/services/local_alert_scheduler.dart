import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/upcoming_alert.dart';

class LocalAlertSyncResult {
  const LocalAlertSyncResult({
    required this.enabled,
    required this.scheduled,
    required this.shownNow,
  });

  final bool enabled;
  final int scheduled;
  final int shownNow;
}

abstract class LocalAlertScheduler {
  Future<void> initialize();
  Future<bool> requestPermission();
  Future<LocalAlertSyncResult> sync(UpcomingAlertsPayload payload);
  Future<void> clear();
}

class NoopLocalAlertScheduler implements LocalAlertScheduler {
  const NoopLocalAlertScheduler();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<LocalAlertSyncResult> sync(UpcomingAlertsPayload payload) async =>
      const LocalAlertSyncResult(enabled: false, scheduled: 0, shownNow: 0);

  @override
  Future<void> clear() async {}
}

class FlutterLocalAlertScheduler implements LocalAlertScheduler {
  FlutterLocalAlertScheduler({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _payloadPrefix = 'fleurapp-upcoming:';
  static const _shownPreferenceKey = 'shown_upcoming_alerts_v1';
  static const _notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'fleurapp_upcoming',
      'Arrivages et commandes',
      channelDescription:
          'Rappels J-1 pour les arrivages, commandes et nomenclatures.',
      icon: 'ic_notification',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.private,
      groupKey: 'fleurapp_upcoming',
      category: AndroidNotificationCategory.reminder,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      threadIdentifier: 'fleurapp_upcoming',
    ),
  );

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Paris'));
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings);
    _initialized = true;
  }

  @override
  Future<bool> requestPermission() async {
    await initialize();
    if (Platform.isAndroid) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          false;
    }
    if (Platform.isIOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return false;
  }

  Future<bool> _notificationsEnabled() async {
    if (Platform.isAndroid) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.areNotificationsEnabled() ??
          false;
    }
    if (Platform.isIOS) {
      final permissions = await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.checkPermissions();
      return permissions?.isEnabled ?? false;
    }
    return false;
  }

  @override
  Future<LocalAlertSyncResult> sync(UpcomingAlertsPayload payload) async {
    await initialize();
    final location = _location(payload.timeZone);
    final alertsByNotificationId = <int, UpcomingAlert>{
      for (final alert in payload.alerts) _notificationId(alert.id): alert,
    };
    final pending = await _plugin.pendingNotificationRequests();
    for (final notification in pending) {
      if ((notification.payload ?? '').startsWith(_payloadPrefix) &&
          !alertsByNotificationId.containsKey(notification.id)) {
        await _plugin.cancel(notification.id);
      }
    }

    final enabled = await _notificationsEnabled();
    if (!enabled) {
      return const LocalAlertSyncResult(
        enabled: false,
        scheduled: 0,
        shownNow: 0,
      );
    }

    final now = DateTime.now();
    final preferences = await SharedPreferences.getInstance();
    final activeAlertIds = payload.alerts.map((alert) => alert.id).toSet();
    final shown = (preferences.getStringList(_shownPreferenceKey) ?? const [])
        .where(activeAlertIds.contains)
        .toSet();
    var scheduled = 0;
    var shownNow = 0;

    for (final entry in alertsByNotificationId.entries) {
      final alert = entry.value;
      await _plugin.cancel(entry.key);
      if (!alert.eventAt.isAfter(now)) continue;
      final payloadValue = '$_payloadPrefix${alert.id}';
      if (alert.remindAt.isAfter(now)) {
        await _plugin.zonedSchedule(
          entry.key,
          alert.title,
          alert.message,
          tz.TZDateTime.from(alert.remindAt, location),
          _notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payloadValue,
        );
        scheduled += 1;
      } else if (shown.add(alert.id)) {
        await _plugin.show(
          entry.key,
          alert.title,
          alert.message,
          _notificationDetails,
          payload: payloadValue,
        );
        shownNow += 1;
      }
    }
    await preferences.setStringList(
        _shownPreferenceKey, shown.toList()..sort());
    return LocalAlertSyncResult(
      enabled: true,
      scheduled: scheduled,
      shownNow: shownNow,
    );
  }

  tz.Location _location(String name) {
    try {
      return tz.getLocation(name);
    } catch (_) {
      return tz.getLocation('Europe/Paris');
    }
  }

  int _notificationId(String value) {
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  @override
  Future<void> clear() async {
    if (!_initialized) return;
    await _plugin.cancelAll();
  }
}
