/// Player color utilities for Nertz Royale
/// Handles color assignment and conversion for player identification

import 'dart:math';
import 'package:flutter/material.dart';

class PlayerColors {
  // Available player colors
  static const Color blue = Color(0xFF2196F3);
  static const Color red = Color(0xFFF44336);
  static const Color green = Color(0xFF4CAF50);
  static const Color orange = Color(0xFFFF9800);
  
  static const List<Color> availableColors = [blue, red, green, orange];
  
  /// Convert Color to int for JSON serialization
  static int colorToInt(Color color) => color.value; // ignore: deprecated_member_use
  
  /// Convert int to Color from JSON
  static Color? intToColor(int? colorInt) {
    if (colorInt == null) return null;
    return Color(colorInt);
  }
  
  /// Get a random player color
  static Color getRandomColor(Random? random) {
    final rng = random ?? Random();
    return availableColors[rng.nextInt(availableColors.length)];
  }
  
  /// Assign colors to players, ensuring no duplicates if possible
  static Map<String, Color> assignColors(List<String> playerIds, {Random? random}) {
    final rng = random ?? Random();
    final assignments = <String, Color>{};
    final usedColors = <Color>[];
    
    for (final playerId in playerIds) {
      Color selectedColor;
      
      if (usedColors.length < availableColors.length) {
        // Pick from unused colors
        final available = availableColors.where((c) => !usedColors.contains(c)).toList();
        selectedColor = available[rng.nextInt(available.length)];
      } else {
        // All colors used, pick any
        selectedColor = availableColors[rng.nextInt(availableColors.length)];
      }
      
      assignments[playerId] = selectedColor;
      usedColors.add(selectedColor);
    }
    
    return assignments;
  }
}
