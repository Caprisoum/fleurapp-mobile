enum UpcomingAlertType { arrival, order, bom, unknown }

enum UpcomingAlertSeverity { info, warning, critical }

class UpcomingAlert {
  const UpcomingAlert({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.message,
    required this.eventAt,
    required this.remindAt,
    required this.hoursUntil,
    required this.data,
  });

  final String id;
  final UpcomingAlertType type;
  final UpcomingAlertSeverity severity;
  final String title;
  final String message;
  final DateTime eventAt;
  final DateTime remindAt;
  final int hoursUntil;
  final Map<String, dynamic> data;

  factory UpcomingAlert.fromJson(Map<String, dynamic> json) {
    final eventAt = DateTime.tryParse('${json['eventAt'] ?? ''}');
    final remindAt = DateTime.tryParse('${json['remindAt'] ?? ''}');
    if (eventAt == null || remindAt == null) {
      throw const FormatException('Date d’alerte invalide.');
    }
    final rawData = json['data'];
    return UpcomingAlert(
      id: '${json['id'] ?? ''}',
      type: switch (json['type']) {
        'arrival' => UpcomingAlertType.arrival,
        'order' => UpcomingAlertType.order,
        'bom' => UpcomingAlertType.bom,
        _ => UpcomingAlertType.unknown,
      },
      severity: switch (json['severity']) {
        'critical' => UpcomingAlertSeverity.critical,
        'warning' => UpcomingAlertSeverity.warning,
        _ => UpcomingAlertSeverity.info,
      },
      title: '${json['title'] ?? 'Alerte FleurApp'}',
      message: '${json['message'] ?? ''}',
      eventAt: eventAt,
      remindAt: remindAt,
      hoursUntil: _integer(json['hoursUntil']),
      data: rawData is Map
          ? Map<String, dynamic>.from(rawData)
          : const <String, dynamic>{},
    );
  }
}

class UpcomingAlertSummary {
  const UpcomingAlertSummary({
    required this.total,
    required this.arrivals,
    required this.orders,
    required this.bomAlerts,
    required this.critical,
  });

  final int total;
  final int arrivals;
  final int orders;
  final int bomAlerts;
  final int critical;

  factory UpcomingAlertSummary.fromJson(Map<String, dynamic> json) =>
      UpcomingAlertSummary(
        total: _integer(json['total']),
        arrivals: _integer(json['arrivals']),
        orders: _integer(json['orders']),
        bomAlerts: _integer(json['bomAlerts']),
        critical: _integer(json['critical']),
      );
}

class UpcomingAlertsPayload {
  const UpcomingAlertsPayload({
    required this.generatedAt,
    required this.windowEnd,
    required this.timeZone,
    required this.summary,
    required this.alerts,
  });

  final DateTime generatedAt;
  final DateTime windowEnd;
  final String timeZone;
  final UpcomingAlertSummary summary;
  final List<UpcomingAlert> alerts;

  factory UpcomingAlertsPayload.fromJson(Map<String, dynamic> json) {
    final generatedAt = DateTime.tryParse('${json['generatedAt'] ?? ''}');
    final rawWindow = json['window'];
    final rawSummary = json['summary'];
    final rawNotifications = json['notifications'];
    if (generatedAt == null ||
        rawWindow is! Map ||
        rawSummary is! Map ||
        rawNotifications is! List) {
      throw const FormatException('Centre d’alertes illisible.');
    }
    final window = Map<String, dynamic>.from(rawWindow);
    final windowEnd = DateTime.tryParse('${window['to'] ?? ''}');
    if (windowEnd == null) {
      throw const FormatException('Fenêtre d’alertes invalide.');
    }
    return UpcomingAlertsPayload(
      generatedAt: generatedAt,
      windowEnd: windowEnd,
      timeZone: '${window['timeZone'] ?? 'Europe/Paris'}',
      summary: UpcomingAlertSummary.fromJson(
        Map<String, dynamic>.from(rawSummary),
      ),
      alerts: rawNotifications
          .map((item) => UpcomingAlert.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(growable: false),
    );
  }
}

int _integer(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
