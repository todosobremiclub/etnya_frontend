import 'package:flutter/material.dart';

class AppTheme {
  static const brandPrimary   = Color(0xFF0E3A5D); // reemplazar
  static const brandSecondary = Color(0xFF00A896); // reemplazar
  static const brandAccent    = Color(0xFFFFC107); // reemplazar
  static const pagoOk         = Color(0xFF2E7D32);
  static const pagoMora       = Color(0xFFC62828);

  static ThemeData theme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: brandPrimary,
        primary: brandPrimary,
        secondary: brandSecondary,
      ),
      useMaterial3: true,
    );
  }
}
