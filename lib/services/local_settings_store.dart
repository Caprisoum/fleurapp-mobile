import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/app_config.dart';

class LocalSettings {
  const LocalSettings({required this.apiBaseUrl, required this.themeMode});

  final String apiBaseUrl;
  final ThemeMode themeMode;
}

abstract class LocalSettingsStore {
  Future<LocalSettings> read();
  Future<void> writeApiBaseUrl(String value);
  Future<void> writeThemeMode(ThemeMode value);
}

class PreferencesLocalSettingsStore implements LocalSettingsStore {
  static const _apiUrlKey = 'api_base_url';
  static const _themeKey = 'theme_mode';

  @override
  Future<LocalSettings> read() async {
    final preferences = await SharedPreferences.getInstance();
    final savedUrl = preferences.getString(_apiUrlKey)?.trim();
    final savedTheme = preferences.getString(_themeKey);
    return LocalSettings(
      apiBaseUrl: AppConfig.allowServerConfiguration &&
              savedUrl != null &&
              savedUrl.isNotEmpty
          ? savedUrl
          : AppConfig.apiBaseUrl,
      themeMode: switch (savedTheme) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
    );
  }

  @override
  Future<void> writeApiBaseUrl(String value) async {
    if (!AppConfig.allowServerConfiguration) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_apiUrlKey, value);
  }

  @override
  Future<void> writeThemeMode(ThemeMode value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_themeKey, value.name);
  }
}
