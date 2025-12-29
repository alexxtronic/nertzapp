/// Bot difficulty settings provider

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bot_difficulty.dart';

/// Provider for bot difficulty setting
final botDifficultyProvider = StateProvider<BotDifficulty>((ref) {
  return BotDifficulty.medium; // Default to medium
});

/// Provider for points needed to win a match
final pointsToWinProvider = StateProvider<int>((ref) {
  return 100; // Default to 100 points
});

/// Provider for number of bots in offline mode (1-3)
final botCountProvider = StateProvider<int>((ref) {
  return 3; // Default to 3 bots
});
