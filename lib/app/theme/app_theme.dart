import 'package:flutter/material.dart';

class AppTheme {
  static const primaryGreen = Color(0xFF00552F);
  static const brandYellow = Color(0xFFFFD51E);
  static const darkGreen = Color(0xFF004225);
  static const white = Color(0xFFFFFFFF);
  static const lightBackground = Color(0xFFF5F7F2);
  static const primaryText = Color(0xFF202321);
  static const secondaryText = Color(0xFF777C79);

  static final light = ThemeData(
    useMaterial3: true,
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: primaryGreen,
          brightness: Brightness.light,
        ).copyWith(
          primary: primaryGreen,
          onPrimary: white,
          secondary: brandYellow,
          onSecondary: darkGreen,
          surface: white,
          onSurface: primaryText,
          error: const Color(0xFFB63E32),
          onError: white,
        ),
    scaffoldBackgroundColor: lightBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryGreen,
      foregroundColor: white,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: const CardThemeData(
      color: white,
      surfaceTintColor: Colors.transparent,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryGreen,
        foregroundColor: white,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primaryGreen,
        foregroundColor: white,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(foregroundColor: primaryGreen),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: darkGreen,
      selectedItemColor: brandYellow,
      unselectedItemColor: white,
      type: BottomNavigationBarType.fixed,
    ),
  );
}
