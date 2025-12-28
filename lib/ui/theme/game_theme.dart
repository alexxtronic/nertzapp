/// Game theme for Nertz Royale

library;

import 'package:flutter/material.dart';
import 'dart:ui'; // For ImageFilter

/// Main theme configuration
class GameTheme {
  // Brand colors (Pastel/Dreamy)
  static const Color primary = Color(0xFF8B5CF6); // Soft Violet
  static const Color secondary = Color(0xFFF472B6); // Soft Pink
  static const Color accent = Color(0xFF38BDF8); // Sky Blue
  
  // Card colors
  static const Color cardRed = Color(0xFFE11D48); // Rose Red
  static const Color cardBlack = Color(0xFF1E293B); // Navy Blue
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFE2E8F0);
  
  // High contrast mode colors
  static const Color cardRedHighContrast = Color(0xFFDC2626);
  static const Color cardBlackHighContrast = Color(0xFF000000);
  
  // UI colors
  static const Color backgroundStart = Color(0xFFF3E8FF); // Lavender Mist
  static const Color backgroundEnd = Color(0xFFE0F2FE); // Pale Sky
  
  static const Color glassSurface = Color(0x80FFFFFF); // 50% White
  static const Color glassBorder = Color(0x40FFFFFF); // 25% White
  
  static const Color textPrimary = Color(0xFF1E293B); // Slate 800
  static const Color textSecondary = Color(0xFF64748B); // Slate 500
  static const Color textOnDark = Color(0xFFF8FAFC); // Slate 50
  
  // Status colors
  static const Color success = Color(0xFF10B981); // Emerald
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color error = Color(0xFFEF4444); // Red
  
  // Legacy compatibility aliases
  static const Color background = backgroundStart;
  static const Color surface = glassSurface;
  static const Color surfaceLight = Color(0x99FFFFFF); // 60% White
  static const Color cardBackground = Colors.white;

  // Gradients
  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [backgroundStart, backgroundEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient glassGradient = LinearGradient(
    colors: [
      Color(0x99FFFFFF), // 60% White
      Color(0x66FFFFFF), // 40% White
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient pillGradient = LinearGradient(
    colors: [
      Color(0xFF8B5CF6), // Violet
      Color(0xFFC084FC), // Lighter Violet
    ],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Shadows
  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: const Color(0xFF64748B).withValues(alpha: 0.1),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: const Color(0xFF64748B).withValues(alpha: 0.15),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];
  
  // Card dimensions and animations
  static const double cardWidth = 64.0;
  static const double cardHeight = 96.0;
  static const double cardRadius = 12.0;
  static const double cardStackOffset = 24.0;
  static const Duration cardFlipDuration = Duration(milliseconds: 300);
  static const Duration cardHighlightDuration = Duration(milliseconds: 200);
  
  static List<BoxShadow> cardHoverShadow = [
    BoxShadow(
      color: primary.withValues(alpha: 0.3),
      blurRadius: 12,
      spreadRadius: 2,
    ),
  ];
  
  static List<BoxShadow> cardDraggingShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.2),
      blurRadius: 15,
      spreadRadius: 5,
      offset: const Offset(0, 10),
    ),
  ];

  // Decoration for Glassmorphism
  static BoxDecoration glassDecoration = BoxDecoration(
    gradient: glassGradient,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
    boxShadow: softShadow,
  );

  // Typography Tokens
  static const TextStyle h1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );

  static const TextStyle label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.bold,
    color: textSecondary,
    letterSpacing: 1.2,
  );

  static const TextStyle body = TextStyle(
    fontSize: 16,
    color: textPrimary,
  );

  /// Build the Flutter theme data
  static ThemeData buildTheme({bool highContrast = false}) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: Colors.transparent, // Background handled by container
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        secondary: secondary,
        surface: Colors.white.withValues(alpha: 0.8),
        error: error,
      ),
      fontFamily: 'Inter', // Try to use system font if Inter isn't available
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        headlineLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
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
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: primary.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

/// Card style settings based on accessibility mode
class CardStyle {
  final Color redColor;
  final Color blackColor;
  final bool useShapes;
  
  const CardStyle({
    required this.redColor,
    required this.blackColor,
    this.useShapes = false,
  });
  
  static const CardStyle normal = CardStyle(
    redColor: GameTheme.cardRed,
    blackColor: GameTheme.cardBlack,
  );
  
  static const CardStyle highContrast = CardStyle(
    redColor: GameTheme.cardRedHighContrast,
    blackColor: GameTheme.cardBlackHighContrast,
    useShapes: true,
  );
}
