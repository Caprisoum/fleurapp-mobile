import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleurapp_mobile/core/config/app_config.dart';
import 'package:fleurapp_mobile/services/local_settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'api_base_url': 'https://ancienne-instance.onrender.com',
      'theme_mode': 'dark',
    });
  });

  test('la version publique ignore une ancienne URL mémorisée', () async {
    expect(AppConfig.allowServerConfiguration, isFalse);

    final settings = await PreferencesLocalSettingsStore().read();

    expect(settings.apiBaseUrl, 'https://api.fleurapp.fr');
    expect(settings.themeMode, ThemeMode.dark);
  });

  test('la version publique refuse de mémoriser une autre URL', () async {
    final store = PreferencesLocalSettingsStore();

    await store.writeApiBaseUrl('https://tunnel.example.com');

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString('api_base_url'),
      'https://ancienne-instance.onrender.com',
    );
  });
}
