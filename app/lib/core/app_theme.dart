import 'package:flutter/material.dart';

/// MVP design system: territory / running game — bold, energetic, readable.
/// Interval-style vibe: coral gradients, dark cards, strong typography.
class AppTheme {
  AppTheme._();

  // Brand / primary = warm coral. Used for main CTAs.
  static const Color _primary = Color(0xFFFF4B5C);
  static const Color _primaryContainer = Color(0xFFFFD1D8);
  static const Color _onPrimary = Color(0xFF000000);
  static const Color _onPrimaryContainer = Color(0xFF1C0206);

  // Secondary = deep charcoal used for backgrounds / cards.
  static const Color _secondary = Color(0xFF111218);
  static const Color _secondaryContainer = Color(0xFF1E2027);
  static const Color _onSecondary = Color(0xFFFFFFFF);
  static const Color _onSecondaryContainer = Color(0xFFE9E9F0);

  // Surfaces = soft off-white with a hint of peach.
  static const Color _surface = Color(0xFFFFF6F4);
  static const Color _surfaceContainer = Color(0xFFFFECE7);
  static const Color _onSurface = Color(0xFF151317);
  static const Color _onSurfaceVariant = Color(0xFF66616D);
  static const Color _outline = Color(0xFF8C8693);

  static const Color _error = Color(0xFFBA1A1A);
  static const Color _onError = Color(0xFFFFFFFF);
  static const Color _tertiary = Color(0xFF7D5260);
  static const Color _tertiaryContainer = Color(0xFFFFD8E4);

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: _primary,
        onPrimary: _onPrimary,
        primaryContainer: _primaryContainer,
        onPrimaryContainer: _onPrimaryContainer,
        secondary: _secondary,
        onSecondary: _onSecondary,
        secondaryContainer: _secondaryContainer,
        onSecondaryContainer: _onSecondaryContainer,
        surface: _surface,
        onSurface: _onSurface,
        onSurfaceVariant: _onSurfaceVariant,
        surfaceContainerHighest: _surfaceContainer,
        outline: _outline,
        error: _error,
        onError: _onError,
        tertiary: _tertiary,
        onTertiary: _onError,
        tertiaryContainer: _tertiaryContainer,
        onTertiaryContainer: _onSurface,
      ),
      scaffoldBackgroundColor: _surface,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: Colors.transparent,
        foregroundColor: _onSurface,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: _onSurface,
          letterSpacing: 0.2,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: _secondaryContainer,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        clipBehavior: Clip.antiAlias,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.25,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _onSurfaceVariant,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 4,
        highlightElevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        extendedPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        contentTextStyle: const TextStyle(fontSize: 14),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
