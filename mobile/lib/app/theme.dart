import 'package:flutter/material.dart';

/// Application theme.
///
/// Deliberately plain for M1. Visual design belongs with the screens that use
/// it, and UX flows warn against a complex dashboard.
final class AppTheme {
  const AppTheme._();

  static const Color _seed = Color(0xFF1B6B4C);

  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        elevation: 0,
      ),
    );
  }
}
