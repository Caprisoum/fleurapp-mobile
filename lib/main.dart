import 'package:flutter/material.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'services/fleur_api_client.dart';
import 'state/pos_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final apiClient = RenderApiClient(baseUrl: AppConfig.apiBaseUrl);
  final controller = PosController(apiClient: apiClient);

  runApp(FleurApp(controller: controller));
}
