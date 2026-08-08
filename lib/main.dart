import 'package:flutter/material.dart';

import 'app.dart';
import 'services/admin_token_store.dart';
import 'services/fleur_api_client.dart';
import 'services/local_settings_store.dart';
import 'services/local_alert_scheduler.dart';
import 'state/app_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appController = AppController(
    apiClient: RenderApiClient(baseUrl: ''),
    settingsStore: PreferencesLocalSettingsStore(),
    tokenStore: const SecureAdminTokenStore(),
    alertScheduler: FlutterLocalAlertScheduler(),
  );
  await appController.initialize();
  runApp(FleurApp(controller: appController));
}
