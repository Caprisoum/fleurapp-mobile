import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/home/home_shell.dart';
import 'state/app_controller.dart';

class FleurApp extends StatelessWidget {
  const FleurApp({required this.controller, super.key});
  final AppController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) => MaterialApp(
          title: 'FleurApp Caisse',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: controller.themeMode,
          home: HomeShell(appController: controller),
        ),
      );
}
