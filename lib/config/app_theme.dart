import 'package:flutter/material.dart';

class AppTheme {
  // iOS 26 Style - Modern VTB Brand Colors
  static const Color primaryBlue = Color(0xFF003CC5); // Electric Blue (accent)
  static const Color darkBlue = Color(0xFF0A174E); // Dark Blue (primary brand)
  static const Color lightBlue = Color(0xFF4D7EFF);
  static const Color accentBlue = Color(0xFF00C2FF);
  static const Color iceBlue = Color(0xFFF0F5FF); // Ice Blue (background)

  static const Color successGreen = Color(0xFF00C853);
  static const Color warningOrange = Color(0xFFFF6D00);
  static const Color errorRed = Color(0xFFD50000);

  static const Color backgroundLight = Color(0xFFF0F5FF); // Ice Blue
  static const Color backgroundWhite = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFFFFFFF);

  static const Color textPrimary = Color(0xFF0A174E); // Darker, using brand dark blue
  static const Color textSecondary = Color(0xFF5A6B8C); // More muted
  static const Color textHint = Color(0xFFBDBDBD);

  // Gradient definitions for modern iOS 26 style
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0A174E), Color(0xFF003CC5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF003CC5), Color(0xFF4D7EFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF0F5FF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        primary: primaryBlue,
        secondary: accentBlue,
        surface: backgroundWhite,
        background: backgroundLight,
        error: errorRed,
      ),
      scaffoldBackgroundColor: backgroundLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBlue, // Using darker brand color
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0, // Remove elevation, use shadow instead
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20), // Increased from 16
        ),
        color: cardBackground,
        shadowColor: darkBlue.withValues(alpha: 0.08),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8), // More air
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18), // More vertical padding
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16), // More rounded
          ),
          elevation: 0, // Flat design
          shadowColor: primaryBlue.withValues(alpha: 0.3),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryBlue,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: backgroundWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorRed),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: textSecondary,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: textHint,
        ),
      ),
    );
  }

  // Helper method for creating modern iOS 26 style cards with inset shadows
  static BoxDecoration modernCardDecoration({
    Color? backgroundColor,
    Gradient? gradient,
    double borderRadius = 20,
  }) {
    return BoxDecoration(
      color: gradient == null ? (backgroundColor ?? cardBackground) : null,
      gradient: gradient,
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: [
        // Subtle outer shadow
        BoxShadow(
          color: darkBlue.withValues(alpha: 0.06),
          blurRadius: 20,
          offset: const Offset(0, 8),
          spreadRadius: 0,
        ),
        // Inset shadow effect (simulated with inner shadow)
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.7),
          blurRadius: 1,
          offset: const Offset(0, 1),
          spreadRadius: 0,
        ),
      ],
    );
  }

  // Helper method for gradient buttons
  static BoxDecoration gradientButtonDecoration({
    Gradient? gradient,
    double borderRadius = 16,
  }) {
    return BoxDecoration(
      gradient: gradient ?? primaryGradient,
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: [
        BoxShadow(
          color: primaryBlue.withValues(alpha: 0.3),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  // iOS 26 Frosted Glass Effect (Glassmorphism)
  static BoxDecoration glassDecoration({
    Color? color,
    double borderRadius = 20,
    double blur = 10,
    double opacity = 0.1,
  }) {
    return BoxDecoration(
      color: (color ?? Colors.white).withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.2),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: darkBlue.withValues(alpha: 0.05),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  // iOS 26 Bottom Navigation Glass Effect
  static BoxDecoration bottomNavGlassDecoration() {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.8),
      border: Border(
        top: BorderSide(
          color: Colors.white.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      boxShadow: [
        BoxShadow(
          color: darkBlue.withValues(alpha: 0.08),
          blurRadius: 30,
          offset: const Offset(0, -5),
        ),
      ],
    );
  }

  // Quick Action Button Style (iOS 26)
  static BoxDecoration quickActionDecoration({
    required Color color,
    double borderRadius = 16,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [
          color,
          color.withValues(alpha: 0.8),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.3),
          blurRadius: 15,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}
