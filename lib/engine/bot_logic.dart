import '../models/game_state.dart';
import 'move_validator.dart';

/// Simple AI for bot players
class BotLogic {
  
  /// Finds the best move for a bot player
  static Move? findBestMove(GameState gameState, String botId) {
    if (gameState.phase != GamePhase.playing) return null;
    
    final player = gameState.players[botId];
    if (player == null) return null;
    
    // Priority 1: Nertz -> Center (CRITICAL)
    if (player.nertzPile.topCard != null) {
      final move = MoveValidator.getBestAutoMove(player.nertzPile.topCard!.id, botId, gameState);
      if (move != null && move.type == MoveType.toCenter) return move;
    }

    // Priority 2: Waste -> Center
    if (player.wastePile.topCard != null) {
      final move = MoveValidator.getBestAutoMove(player.wastePile.topCard!.id, botId, gameState);
      if (move != null && move.type == MoveType.toCenter) return move;
    }

    // Priority 3: Work -> Center
    for (final pile in player.workPiles) {
      if (pile.topCard != null) {
        final move = MoveValidator.getBestAutoMove(pile.topCard!.id, botId, gameState);
        if (move != null && move.type == MoveType.toCenter) return move;
      }
    }

    // Priority 4: Nertz -> Work (To uncover next Nertz card)
    if (player.nertzPile.topCard != null) {
      final move = MoveValidator.getBestAutoMove(player.nertzPile.topCard!.id, botId, gameState);
      if (move != null && move.type == MoveType.toWorkPile) return move;
    }

    // Priority 5: Waste -> Work
    if (player.wastePile.topCard != null) {
      final move = MoveValidator.getBestAutoMove(player.wastePile.topCard!.id, botId, gameState);
      if (move != null && move.type == MoveType.toWorkPile) return move;
    }

    // Priority 6: Work -> Work (Moving stacks to empty or better slots)
    for (final pile in player.workPiles) {
      if (pile.isEmpty) continue;
      // Try moving the bottom-most movable card of each pile (the whole stack)
      final bottomCard = pile.cards.first; 
      final move = MoveValidator.getBestAutoMove(bottomCard.id, botId, gameState);
      if (move != null && (move.type == MoveType.toWorkPile || move.type == MoveType.moveStack)) {
        // Only move if it's to an empty slot OR if it's a multi-card stack being reorganized
        return move;
      }
    }

    return null;
  }
}
