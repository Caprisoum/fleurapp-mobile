enum BugCategory {
  ui('UI', 'Interface'),
  stock('Stock', 'Stock'),
  payment('Paiement', 'Paiement'),
  crash('Crash', 'Crash'),
  other('Autre', 'Autre');

  const BugCategory(this.apiValue, this.label);
  final String apiValue;
  final String label;
}

enum BugReportStatus {
  newReport('NOUVEAU', 'Nouveau'),
  inProgress('EN_COURS', 'En cours'),
  resolved('RESOLU', 'Résolu');

  const BugReportStatus(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static BugReportStatus parse(Object? value) => values.firstWhere(
        (status) => status.apiValue == value,
        orElse: () => throw const FormatException('Statut de bug inconnu.'),
      );
}

class BugDeviceMetadata {
  const BugDeviceMetadata({
    required this.os,
    required this.model,
    required this.appVersion,
  });

  final String os;
  final String model;
  final String appVersion;
}

class BugReportDraft {
  const BugReportDraft({
    required this.title,
    required this.description,
    required this.category,
    required this.device,
  });

  final String title;
  final String description;
  final BugCategory category;
  final BugDeviceMetadata device;

  Map<String, dynamic> toJson() => {
        'titre': title.trim(),
        'description': description.trim(),
        'categorie': category.apiValue,
        'appareil_info': {'os': device.os, 'modele': device.model},
        'version_app': device.appVersion,
      };
}

class BugReport {
  const BugReport({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.deviceOs,
    required this.deviceModel,
    required this.appVersion,
    required this.status,
    required this.createdAt,
  });

  final int id;
  final String title;
  final String description;
  final String category;
  final String deviceOs;
  final String deviceModel;
  final String appVersion;
  final BugReportStatus status;
  final DateTime createdAt;

  factory BugReport.fromJson(Map<String, dynamic> json) {
    final device = json['appareil_info'];
    if (device is! Map) {
      throw const FormatException('Informations appareil illisibles.');
    }
    final id = json['id'] is num
        ? (json['id'] as num).toInt()
        : int.tryParse('${json['id']}');
    final createdAt = DateTime.tryParse('${json['created_at'] ?? ''}');
    if (id == null || id < 1 || createdAt == null) {
      throw const FormatException('Rapport de bug incomplet.');
    }
    return BugReport(
      id: id,
      title: '${json['titre'] ?? ''}',
      description: '${json['description'] ?? ''}',
      category: '${json['categorie'] ?? ''}',
      deviceOs: '${device['os'] ?? ''}',
      deviceModel: '${device['modele'] ?? ''}',
      appVersion: '${json['version_app'] ?? ''}',
      status: BugReportStatus.parse(json['statut']),
      createdAt: createdAt,
    );
  }

  BugReport withStatus(BugReportStatus value) => BugReport(
        id: id,
        title: title,
        description: description,
        category: category,
        deviceOs: deviceOs,
        deviceModel: deviceModel,
        appVersion: appVersion,
        status: value,
        createdAt: createdAt,
      );
}
