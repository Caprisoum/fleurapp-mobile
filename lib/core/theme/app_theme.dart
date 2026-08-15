import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static const Color forest = Color(0xFF173F35);
  static const Color leaf = Color(0xFF2F6B59);
  static const Color coral = Color(0xFFE76F51);
  static const Color cream = Color(0xFFF8F5EF);
  static const Color ink = Color(0xFF17211E);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: dark ? const Color(0xFF7FC7AF) : forest,
      primary: dark ? const Color(0xFF8BD1B9) : forest,
      secondary: dark ? const Color(0xFFFFA58D) : coral,
      surface: dark ? const Color(0xFF17201D) : Colors.white,
      brightness: brightness,
    );
    final fieldColor = dark ? const Color(0xFF202C28) : Colors.white;
    final borderColor =
        dark ? const Color(0xFF3A4944) : const Color(0xFFDFE7E3);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? const Color(0xFF101714) : cream,
      visualDensity: VisualDensity.standard,
      fontFamily: 'sans-serif',
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? const Color(0xFF101714) : cream,
        foregroundColor: dark ? Colors.white : ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: borderColor),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size.square(48)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark ? const Color(0xFF17201D) : Colors.white,
        indicatorColor:
            dark ? const Color(0xFF29463D) : const Color(0xFFE5F0EB),
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      dividerTheme: DividerThemeData(color: borderColor),
    );
  }
}
