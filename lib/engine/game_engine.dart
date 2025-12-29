/// Game engine for Nertz Royale

library;

import '../models/card.dart';
import '../models/player_state.dart';
import '../models/game_state.dart';
import 'move_validator.dart';

/// Result of executing a move
class ExecutionResult {
  final bool success;
  final String? error;
  final bool roundEnded;
  final String? roundWinnerId;

  ExecutionResult({
    required this.success,
    this.error,
    this.roundEnded = false,
    this.roundWinnerId,
  });

  factory ExecutionResult.success({bool roundEnded = false, String? winnerId}) =>
    ExecutionResult(success: true, roundEnded: roundEnded, roundWinnerId: winnerId);
  
  factory ExecutionResult.failure(String error) =>
    ExecutionResult(success: false, error: error);
}

/// Core game engine
class GameEngine {
  static ExecutionResult executeMove(Move move, GameState gameState) {
    final validation = MoveValidator.validate(move, gameState);
    if (!validation.isValid) {
      return ExecutionResult.failure(validation.errorMessage!);
    }

    final player = gameState.getPlayer(move.playerId)!;

    switch (move.type) {
      case MoveType.drawThree:
        return _executeDrawThree(player);
      case MoveType.drawOne:
        return _executeDrawOne(player);
      case MoveType.toWorkPile:
        return _executeToWorkPile(move, player);
      case MoveType.toCenter:
        return _executeToCenter(move, player, gameState);
      case MoveType.moveStack:
        return _executeMoveStack(move, player);
      case MoveType.callNertz:
        return _executeCallNertz(player);
      case MoveType.voteReset:
        return _executeVoteReset(move, player, gameState);
    }
  }

  static ExecutionResult _executeDrawThree(PlayerState player) {
    player.drawThree();
    return ExecutionResult.success();
  }

  static ExecutionResult _executeDrawOne(PlayerState player) {
    player.drawOne();
    return ExecutionResult.success();
  }

  static ExecutionResult _executeToWorkPile(Move move, PlayerState player) {
    final location = player.findCard(move.cardId!)!;
    
    PlayingCard card;
    switch (location.type) {
      case PileType.nertz:
        card = player.nertzPile.pop()!;
        break;
      case PileType.waste:
        card = player.wastePile.pop()!;
        break;
      case PileType.work:
        card = player.workPiles[location.pileIndex].pop()!;
        break;
      default:
        return ExecutionResult.failure('Invalid source');
    }

    player.workPiles[move.targetPileIndex!].push(card);
    return ExecutionResult.success();
  }

  static ExecutionResult _executeToCenter(Move move, PlayerState player, GameState gameState) {
    final location = player.findCard(move.cardId!)!;
    
    PlayingCard card;
    switch (location.type) {
      case PileType.nertz:
        card = player.nertzPile.pop()!;
        break;
      case PileType.waste:
        card = player.wastePile.pop()!;
        break;
      case PileType.work:
        card = player.workPiles[location.pileIndex].pop()!;
        break;
      default:
        return ExecutionResult.failure('Invalid source');
    }

    // Use the specific pile index the user targeted (no auto-find)
    gameState.playToCenterPile(card, move.targetPileIndex!, playerId: player.id);

    // Removed automatic win trigger - User must press Nertz Button!
    // if (player.hasEmptiedNertz) {
    //   return ExecutionResult.success(roundEnded: true, winnerId: player.id);
    // }

    return ExecutionResult.success();
  }

  static ExecutionResult _executeMoveStack(Move move, PlayerState player) {
    final location = player.findCard(move.cardId!)!;
    final sourcePile = player.workPiles[location.pileIndex];
    final targetPile = player.workPiles[move.targetPileIndex!];

    final cardsToMove = sourcePile.removeCardsFrom(location.cardIndex);
    targetPile.pushAll(cardsToMove);

    return ExecutionResult.success();
  }

  static ExecutionResult _executeCallNertz(PlayerState player) {
    if (player.nertzPile.isEmpty) {
      return ExecutionResult.success(roundEnded: true, winnerId: player.id);
    }
    return ExecutionResult.failure('Nertz pile not empty');
  }

  static ExecutionResult _executeVoteReset(Move move, PlayerState player, GameState gameState) {
    gameState.voteForReset(player.id);
    return ExecutionResult.success();
  }

  static void setupRound(GameState gameState) {
    gameState.startRound();
  }

  static void endRound(GameState gameState, String winnerId) {
    gameState.endRound(winnerId);
  }

  static bool isMatchEnded(GameState gameState) {
    return gameState.phase == GamePhase.matchEnd;
  }

  static List<PlayerState> getMatchWinners(GameState gameState) {
    if (!isMatchEnded(gameState)) return [];

    final maxScore = gameState.players.values
      .map((p) => p.scoreTotal)
      .reduce((a, b) => a > b ? a : b);

    return gameState.players.values
      .where((p) => p.scoreTotal == maxScore)
      .toList();
  }
}
