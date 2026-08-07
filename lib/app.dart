import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/pos/pos_screen.dart';
import 'state/pos_controller.dart';

class FleurApp extends StatefulWidget {
  const FleurApp({
    required this.controller,
    this.autoLoad = true,
    super.key,
  });

  final PosController controller;
  final bool autoLoad;

  @override
  State<FleurApp> createState() => _FleurAppState();
}

class _FleurAppState extends State<FleurApp> {
  @override
  void initState() {
    super.initState();
    if (widget.autoLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.controller.loadProducts();
      });
    }
  }

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FleurApp Caisse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: PosScreen(controller: widget.controller),
    );
  }
}
