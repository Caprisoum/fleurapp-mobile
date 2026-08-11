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
  static const _shownPreferenceKey = 'shown_upcoming_alerts_v2';
  static const _notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'fleurapp_upcoming',
      'Arrivages et commandes',
      channelDescription:
          'Rappels J-1 et le jour J pour les arrivages et commandes.',
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
    final desiredNotificationIds = <int>{};
    for (final alert in payload.alerts) {
      desiredNotificationIds.add(_notificationId('${alert.id}:j-1'));
      if (alert.type == UpcomingAlertType.arrival) {
        desiredNotificationIds.add(_notificationId('${alert.id}:jour-j'));
      }
    }
    final pending = await _plugin.pendingNotificationRequests();
    for (final notification in pending) {
      if ((notification.payload ?? '').startsWith(_payloadPrefix) &&
          !desiredNotificationIds.contains(notification.id)) {
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

    final now = tz.TZDateTime.now(location);
    final preferences = await SharedPreferences.getInstance();
    final activeAlertIds = <String>{
      for (final alert in payload.alerts) '${alert.id}:j-1',
      for (final alert in payload.alerts)
        if (alert.type == UpcomingAlertType.arrival) '${alert.id}:jour-j',
    };
    final shown = (preferences.getStringList(_shownPreferenceKey) ?? const [])
        .where(activeAlertIds.contains)
        .toSet();
    var scheduled = 0;
    var shownNow = 0;

    for (final alert in payload.alerts) {
      final eventAt = tz.TZDateTime.from(alert.eventAt, location);
      final remindAt = tz.TZDateTime.from(alert.remindAt, location);
      final reminderKey = '${alert.id}:j-1';
      final reminderId = _notificationId(reminderKey);
      final payloadValue = '$_payloadPrefix${alert.id}';
      await _plugin.cancel(reminderId);

      if (alert.type == UpcomingAlertType.arrival) {
        final dayKey = '${alert.id}:jour-j';
        final dayId = _notificationId(dayKey);
        await _plugin.cancel(dayId);
        if (_isBeforeDate(eventAt, now)) continue;

        if (_isSameDate(eventAt, now)) {
          if (eventAt.isAfter(now)) {
            await _plugin.zonedSchedule(
              dayId,
              alert.title,
              alert.message,
              eventAt,
              _notificationDetails,
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
              payload: payloadValue,
            );
            scheduled += 1;
          } else if (shown.add(dayKey)) {
            await _plugin.show(
              dayId,
              alert.title,
              alert.message,
              _notificationDetails,
              payload: payloadValue,
            );
            shownNow += 1;
          }
          continue;
        }

        await _plugin.zonedSchedule(
          dayId,
          'Aujourd’hui — ${alert.title.replaceFirst('Arrivage à venir — ', '')}',
          alert.message,
          eventAt,
          _notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payloadValue,
        );
        scheduled += 1;
      } else if (!eventAt.isAfter(now)) {
        continue;
      }

      if (remindAt.isAfter(now)) {
        await _plugin.zonedSchedule(
          reminderId,
          alert.title,
          alert.message,
          remindAt,
          _notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payloadValue,
        );
        scheduled += 1;
      } else if (shown.add(reminderKey)) {
        await _plugin.show(
          reminderId,
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

  bool _isSameDate(tz.TZDateTime left, tz.TZDateTime right) =>
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;

  bool _isBeforeDate(tz.TZDateTime left, tz.TZDateTime right) {
    final leftDate = DateTime(left.year, left.month, left.day);
    final rightDate = DateTime(right.year, right.month, right.day);
    return leftDate.isBefore(rightDate);
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
