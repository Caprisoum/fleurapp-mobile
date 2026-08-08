import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/bug_report.dart';

abstract class DeviceMetadataService {
  Future<BugDeviceMetadata> load();
}

class FallbackDeviceMetadataService implements DeviceMetadataService {
  const FallbackDeviceMetadataService();

  @override
  Future<BugDeviceMetadata> load() async => const BugDeviceMetadata(
        os: 'Système inconnu',
        model: 'Appareil inconnu',
        appVersion: 'inconnue',
      );
}

class FlutterDeviceMetadataService implements DeviceMetadataService {
  FlutterDeviceMetadataService({DeviceInfoPlugin? deviceInfo})
      : _deviceInfo = deviceInfo ?? DeviceInfoPlugin();

  final DeviceInfoPlugin _deviceInfo;

  @override
  Future<BugDeviceMetadata> load() async {
    String os = 'Système inconnu';
    String model = 'Appareil inconnu';
    String version = 'inconnue';
    try {
      final package = await PackageInfo.fromPlatform();
      version = package.buildNumber.isEmpty
          ? package.version
          : '${package.version}+${package.buildNumber}';
    } catch (_) {
      // Le rapport doit rester disponible même si le plugin est indisponible.
    }
    try {
      if (kIsWeb) {
        final info = await _deviceInfo.webBrowserInfo;
        os = info.platform ?? 'Web';
        model = info.userAgent ?? info.browserName.name;
      } else {
        switch (defaultTargetPlatform) {
          case TargetPlatform.android:
            final info = await _deviceInfo.androidInfo;
            os = 'Android ${info.version.release} (SDK ${info.version.sdkInt})';
            model = _cleanModel(info.manufacturer, info.model);
          case TargetPlatform.iOS:
            final info = await _deviceInfo.iosInfo;
            os = '${info.systemName} ${info.systemVersion}';
            model = '${info.model} (${info.utsname.machine})';
          case TargetPlatform.macOS:
            os = 'macOS';
            model = 'Mac';
          case TargetPlatform.windows:
            os = 'Windows';
            model = 'PC Windows';
          case TargetPlatform.linux:
            os = 'Linux';
            model = 'PC Linux';
          case TargetPlatform.fuchsia:
            os = 'Fuchsia';
            model = 'Appareil Fuchsia';
        }
      }
    } catch (_) {
      os = defaultTargetPlatform.name;
    }
    return BugDeviceMetadata(
      os: _bounded(os, 100),
      model: _bounded(model, 180),
      appVersion: _bounded(version, 60),
    );
  }

  String _cleanModel(String manufacturer, String model) {
    final maker = manufacturer.trim();
    final deviceModel = model.trim();
    if (deviceModel.toLowerCase().startsWith(maker.toLowerCase())) {
      return deviceModel;
    }
    return '$maker $deviceModel'.trim();
  }

  String _bounded(String value, int maxLength) {
    final normalized =
        value.replaceAll(RegExp(r'[\u0000-\u001F\u007F<>]'), ' ').trim();
    final safe = normalized.isEmpty ? 'Inconnu' : normalized;
    return safe.length <= maxLength ? safe : safe.substring(0, maxLength);
  }
}
