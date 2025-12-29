/// Bot difficulty settings provider

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bot_difficulty.dart';

/// Provider for bot difficulty setting
final botDifficultyProvider = StateProvider<BotDifficulty>((ref) {
  return BotDifficulty.medium; // Default to medium
});
