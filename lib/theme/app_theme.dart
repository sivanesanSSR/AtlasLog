import 'package:flutter/material.dart';

/// Central theming for Gym Manager — dark theme with a black/orange
/// gradient accent, matching the app's brand mood board (deep charcoal
/// surfaces, warm amber-to-red-orange gradient highlights).
class AppTheme {
  AppTheme._();

  // Core surfaces
  static const Color background = Color(0xFF121212);
  static const Color surface = Color(0xFF1E1E1E);
  static const Color surfaceRaised = Color(0xFF242424);
  static const Color surfaceBorder = Color(0xFF333333);

  // Brand palette
  static const Color primary = Color(0xFFFF8C00); // orange (mid gradient stop)
  static const Color primaryDark = Color(0xFFE0630A);
  static const Color secondary = Color(0xFF000000);
  static const Color success = Color(0xFF3DBE5B);
  static const Color warning = Color(0xFFF9A825);
  static const Color danger = Color(0xFFE05252);

  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFFAAAAAA);

  /// The gradient used for the "padding-box" fill in the CSS reference —
  /// applied as the visible gradient surface (buttons, active states).
  static const List<Color> fillGradientColors = [
    Color(0xFFFFB300),
    Color(0xFFFF8C00),
    Color(0xFFFF5A00),
  ];

  /// The gradient used for the "border-box" outline in the CSS
  /// reference — slightly lighter/warmer, used as a ring around dark
  /// surfaces (e.g. active dashboard filter cards).
  static const List<Color> borderGradientColors = [
    Color(0xFFFFD54F),
    Color(0xFFFF8C00),
    Color(0xFFFF4500),
  ];

  static const LinearGradient fillGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: fillGradientColors,
    stops: [0.0, 0.45, 1.0],
  );

  static const LinearGradient borderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: borderGradientColors,
    stops: [0.0, 0.45, 1.0],
  );

  /// Kept for compatibility with earlier code that referenced this name.
  static const List<Color> activeGradientColors = borderGradientColors;

  static ThemeData get lightTheme => _buildTheme(isDark: false);
  static ThemeData get darkTheme => _buildTheme(isDark: true);

  static ThemeData _buildTheme({required bool isDark}) {
    final bg = isDark ? background : const Color(0xFFF7F5F2);
    final surf = isDark ? surface : Colors.white;
    final surfRaised = isDark ? surfaceRaised : const Color(0xFFF0EEEA);
    final border = isDark ? surfaceBorder : const Color(0xFFE0DDD6);
    final textP = isDark ? textPrimary : const Color(0xFF1A1A1A);
    final textS = isDark ? textSecondary : const Color(0xFF6B6B6B);
    final appBarBg = isDark ? secondary : const Color(0xFF1A1A1A);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: primary,
      secondary: primary,
      surface: surf,
      error: danger,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bg,
      fontFamily: 'Roboto',
      textTheme: TextTheme(
        headlineMedium: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5, color: textP),
        headlineSmall: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3, color: textP),
        titleLarge: TextStyle(fontWeight: FontWeight.w700, color: textP),
        titleMedium: TextStyle(fontWeight: FontWeight.w600, color: textP),
        bodyLarge: TextStyle(fontWeight: FontWeight.w400, color: textP),
        bodyMedium: TextStyle(color: textP),
        labelLarge: TextStyle(fontWeight: FontWeight.w600, color: textP),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBg,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surf,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textP,
          side: BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfRaised,
        labelStyle: TextStyle(color: textS),
        hintStyle: TextStyle(color: textS),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: danger),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfRaised,
        selectedColor: primary.withOpacity(0.25),
        labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: textP),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1),
      drawerTheme: DrawerThemeData(backgroundColor: surf, surfaceTintColor: Colors.transparent),
      listTileTheme: ListTileThemeData(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        textColor: textP,
        iconColor: textS,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: surfRaised,
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surf,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
      ),
    );
  }
}
