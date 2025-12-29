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
  
  static const Color glassSurface = Color(0xFFFFFFFF); // Solid White
  static const Color glassBorder = Color(0xFFE2E8F0); // Solid Light Grey
  
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
  static const Color surfaceLight = Color(0xFFF8FAFC); // Solid Very Light Grey
  static const Color cardBackground = Colors.white;

  // Gradients
  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [backgroundStart, backgroundEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient glassGradient = LinearGradient(
    colors: [
      Color(0xFFFFFFFF), // Solid White
      Color(0xFFF8FAFC), // Solid Off-White
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
  
  // ========================================
  // SPACING SCALE (8pt grid)
  // ========================================
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;
  static const double spacing40 = 40.0;
  static const double spacing48 = 48.0;
  
  // ========================================
  // BORDER RADIUS SCALE
  // ========================================
  static const double radius8 = 8.0;
  static const double radius12 = 12.0;
  static const double radius14 = 14.0;
  static const double radius16 = 16.0;
  static const double radius20 = 20.0;
  static const double radius24 = 24.0;
  static const double radius30 = 30.0;
  
  // ========================================
  // ANIMATION DURATIONS
  // ========================================
  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animNormal = Duration(milliseconds: 300);
  static const Duration animSlow = Duration(milliseconds: 500);
  
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

  // Decoration for Glassmorphism (Now Solid)
  static BoxDecoration glassDecoration = BoxDecoration(
    gradient: glassGradient,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: glassBorder, width: 2),
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

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    color: textSecondary,
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
          elevation: 0, // Modern flat style
          shadowColor: primary.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius16),
          ),
          animationDuration: animFast,
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return Colors.white.withValues(alpha: 0.2);
            }
            if (states.contains(WidgetState.hovered)) {
              return Colors.white.withValues(alpha: 0.1);
            }
            return null;
          }),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius16),
          ),
          animationDuration: animFast,
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return primary.withValues(alpha: 0.15);
            }
            if (states.contains(WidgetState.hovered)) {
              return primary.withValues(alpha: 0.08);
            }
            return null;
          }),
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
