/// Bot difficulty levels for Nertz Royale

library;

enum BotDifficulty {
  easy,
  medium,
  hard,
  extreme;
  
  /// Get delay in milliseconds between bot moves
  int get delayMs {
    switch (this) {
      case BotDifficulty.easy:
        return 3000; // 3 seconds
      case BotDifficulty.medium:
        return 2500; // 2.5 seconds
      case BotDifficulty.hard:
        return 2000; // 2 seconds
      case BotDifficulty.extreme:
        return 1500; // 1.5 seconds
    }
  }
  
  /// Display name for UI
  String get displayName {
    switch (this) {
      case BotDifficulty.easy:
        return 'Easy';
      case BotDifficulty.medium:
        return 'Medium';
      case BotDifficulty.hard:
        return 'Hard';
      case BotDifficulty.extreme:
        return 'Extreme';
    }
  }
  
  /// Description for each difficulty
  String get description {
    switch (this) {
      case BotDifficulty.easy:
        return '3 second delay - Relaxed pace';
      case BotDifficulty.medium:
        return '2.5 second delay - Balanced pace';
      case BotDifficulty.hard:
        return '2 second delay - Fast pace';
      case BotDifficulty.extreme:
        return '1.5 second delay - Lightning fast!';
    }
  }
  
  /// Icon for difficulty level
  String get emoji {
    switch (this) {
      case BotDifficulty.easy:
        return '🐢';
      case BotDifficulty.medium:
        return '🐇';
      case BotDifficulty.hard:
        return '🚀';
      case BotDifficulty.extreme:
        return '⚡';
    }
  }
}
