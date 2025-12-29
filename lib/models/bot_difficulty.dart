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
        return 10000; // 10 seconds
      case BotDifficulty.medium:
        return 7500; // 7.5 seconds
      case BotDifficulty.hard:
        return 4000; // 4 seconds
      case BotDifficulty.extreme:
        return 2000; // 2 seconds
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
        return 'Relaxed pace';
      case BotDifficulty.medium:
        return 'Balanced pace';
      case BotDifficulty.hard:
        return 'Fast pace';
      case BotDifficulty.extreme:
        return 'Lightning fast!';
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
