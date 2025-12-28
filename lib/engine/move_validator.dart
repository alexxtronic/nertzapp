/// Move validator for Nertz Royale

library;

import '../models/card.dart';
import '../models/player_state.dart';
import '../models/game_state.dart';

/// Types of moves that can be made
enum MoveType {
  toWorkPile,
  toCenter,
  drawThree,
  moveStack,
  drawOne,
  callNertz,
}

/// Represents a move request
class Move {
  final MoveType type;
  final String playerId;
  final String? cardId;
  final int? targetPileIndex;
  final Suit? targetSuit;
  final int? sourceCardIndex;
  final DateTime timestamp;

  Move({
    required this.type,
    required this.playerId,
    this.cardId,
    this.targetPileIndex,
    this.targetSuit,
    this.sourceCardIndex,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'type': type.index,
    'playerId': playerId,
    'cardId': cardId,
    'targetPileIndex': targetPileIndex,
    'targetSuit': targetSuit?.index,
    'sourceCardIndex': sourceCardIndex,
    'timestamp': timestamp.toIso8601String(),
  };

  factory Move.fromJson(Map<String, dynamic> json) => Move(
    type: MoveType.values[json['type'] as int],
    playerId: json['playerId'] as String,
    cardId: json['cardId'] as String?,
    targetPileIndex: json['targetPileIndex'] as int?,
    targetSuit: json['targetSuit'] != null 
      ? Suit.values[json['targetSuit'] as int] 
      : null,
    sourceCardIndex: json['sourceCardIndex'] as int?,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
}

/// Result of move validation
class MoveResult {
  final bool isValid;
  final String? errorMessage;
  final Move move;

  MoveResult({
    required this.isValid,
    this.errorMessage,
    required this.move,
  });

  factory MoveResult.valid(Move move) => MoveResult(isValid: true, move: move);
  factory MoveResult.invalid(Move move, String reason) => 
    MoveResult(isValid: false, errorMessage: reason, move: move);
}

/// Validates moves according to Nertz rules
class MoveValidator {
  static MoveResult validate(Move move, GameState gameState) {
    final player = gameState.getPlayer(move.playerId);
    if (player == null) {
      return MoveResult.invalid(move, 'Player not found');
    }

    if (gameState.phase != GamePhase.playing) {
      return MoveResult.invalid(move, 'Game is not in playing phase');
    }

    switch (move.type) {
      case MoveType.drawThree:
        return _validateDrawThree(move, player);
      case MoveType.drawOne:
        return _validateDrawThree(move, player); // Same validation logic
      case MoveType.toWorkPile:
        return _validateToWorkPile(move, player);
      case MoveType.toCenter:
        return _validateToCenter(move, player, gameState);
      case MoveType.moveStack:
        return _validateMoveStack(move, player);
      case MoveType.callNertz:
        return _validateCallNertz(move, player);
    }
  }

  static MoveResult _validateCallNertz(Move move, PlayerState player) {
    if (!player.nertzPile.isEmpty) {
      return MoveResult.invalid(move, 'Nertz pile is not empty!');
    }
    return MoveResult.valid(move);
  }

  static MoveResult _validateDrawThree(Move move, PlayerState player) {
    if (player.stockPile.isEmpty && player.wastePile.isEmpty) {
      return MoveResult.invalid(move, 'No cards to draw');
    }
    return MoveResult.valid(move);
  }

  static MoveResult _validateToWorkPile(Move move, PlayerState player) {
    if (move.cardId == null) {
      return MoveResult.invalid(move, 'No card specified');
    }
    if (move.targetPileIndex == null || 
        move.targetPileIndex! < 0 || 
        move.targetPileIndex! > 3) {
      return MoveResult.invalid(move, 'Invalid target pile index');
    }

    final location = player.findCard(move.cardId!);
    if (location == null) {
      return MoveResult.invalid(move, 'Card not found in player piles');
    }

    PlayingCard? card;
    switch (location.type) {
      case PileType.nertz:
        card = player.nertzPile.topCard;
        break;
      case PileType.waste:
        card = player.wastePile.topCard;
        break;
      case PileType.work:
        card = player.workPiles[location.pileIndex].topCard;
        break;
      default:
        return MoveResult.invalid(move, 'Cannot move from this pile type');
    }

    if (card == null || card.id != move.cardId) {
      return MoveResult.invalid(move, 'Card is not accessible');
    }

    final targetPile = player.workPiles[move.targetPileIndex!];
    if (!targetPile.canAdd(card)) {
      final targetTop = targetPile.topCard;
      if (targetTop == null) {
        return MoveResult.valid(move);
      }
      return MoveResult.invalid(move, 
        'Cannot place ${card.display} on ${targetTop.display}');
    }

    return MoveResult.valid(move);
  }

  static MoveResult _validateToCenter(Move move, PlayerState player, GameState gameState) {
    if (move.cardId == null) {
      return MoveResult.invalid(move, 'No card specified');
    }
    
    // Hardening: strictly validate targetPileIndex
    final centerPiles = gameState.centerPiles; // Typically 4*players (e.g. 16)
    if (move.targetPileIndex == null || 
        move.targetPileIndex! < 0 || 
        move.targetPileIndex! >= centerPiles.length) {
       return MoveResult.invalid(move, 'Invalid center pile index');
    }

    final location = player.findCard(move.cardId!);
    if (location == null) {
      return MoveResult.invalid(move, 'Card not found in player piles');
    }

    PlayingCard? card;
    switch (location.type) {
      case PileType.nertz:
        card = player.nertzPile.topCard;
        break;
      case PileType.waste:
        card = player.wastePile.topCard;
        break;
      case PileType.work:
        card = player.workPiles[location.pileIndex].topCard;
        break;
      default:
        return MoveResult.invalid(move, 'Cannot move from this pile type');
    }

    if (card == null || card.id != move.cardId) {
      return MoveResult.invalid(move, 'Card is not accessible');
    }

    // Use new findCenterPileFor method for 16 generic slots
    if (!gameState.canPlayToCenter(card)) {
      if (card.rank == Rank.ace) {
        return MoveResult.invalid(move, 'No empty center pile available');
      }
      return MoveResult.invalid(move, 
        'No matching center pile for ${card.display}');
    }

    return MoveResult.valid(move);
  }

  static MoveResult _validateMoveStack(Move move, PlayerState player) {
    if (move.cardId == null) {
      return MoveResult.invalid(move, 'No card specified');
    }
    if (move.targetPileIndex == null || 
        move.targetPileIndex! < 0 || 
        move.targetPileIndex! > 3) {
      return MoveResult.invalid(move, 'Invalid target pile index');
    }

    final location = player.findCard(move.cardId!);
    if (location == null || location.type != PileType.work) {
      return MoveResult.invalid(move, 'Stack moves only work from work piles');
    }

    if (location.pileIndex == move.targetPileIndex) {
      return MoveResult.invalid(move, 'Cannot move to same pile');
    }

    final sourcePile = player.workPiles[location.pileIndex];
    final targetPile = player.workPiles[move.targetPileIndex!];
    
    if (location.cardIndex < 0 || location.cardIndex >= sourcePile.cards.length) {
      return MoveResult.invalid(move, 'Invalid card index');
    }
    
    // Get the cards to be moved (from cardIndex to end)
    final cardsToMove = sourcePile.getCardsFrom(location.cardIndex);
    if (cardsToMove.isEmpty) {
      return MoveResult.invalid(move, 'No cards to move');
    }
    
    // Validate the sequence follows solitaire rules (alternating colors, descending ranks)
    final sequenceValid = _isValidSolitaireSequence(cardsToMove);
    if (!sequenceValid) {
      return MoveResult.invalid(move, 'Cards must alternate colors and descend in rank');
    }
    
    // Validate the top card of moving stack can be placed on target
    final topCardOfStack = cardsToMove.first;
    if (!targetPile.canAdd(topCardOfStack)) {
      final targetTop = targetPile.topCard;
      if (targetTop == null) {
        // Empty pile - any card can start (or enforce King-only if you prefer)
        return MoveResult.valid(move);
      }
      return MoveResult.invalid(move, 
        'Cannot place ${topCardOfStack.display} on ${targetTop.display}');
    }

    return MoveResult.valid(move);
  }
  
  /// Check if a sequence of cards follows solitaire rules:
  /// alternating colors and descending ranks
  static bool _isValidSolitaireSequence(List<PlayingCard> cards) {
    if (cards.length <= 1) return true;
    
    for (int i = 0; i < cards.length - 1; i++) {
      final current = cards[i];
      final next = cards[i + 1];
      
      // Must alternate colors
      if (current.color == next.color) return false;
      
      // Must descend by exactly 1 rank
      if (current.rank.value != next.rank.value + 1) return false;
    }
    
    return true;
  }

  static List<Move> getValidMoves(String playerId, GameState gameState) {
    final player = gameState.getPlayer(playerId);
    if (player == null || gameState.phase != GamePhase.playing) {
      return [];
    }

    final validMoves = <Move>[];

    for (final card in player.getPlayableCards()) {
      if (gameState.canPlayToCenter(card)) {
        validMoves.add(Move(
          type: MoveType.toCenter,
          playerId: playerId,
          cardId: card.id,
          targetSuit: card.suit,
        ));
      }

      for (var i = 0; i < 4; i++) {
        final targetPile = player.workPiles[i];
        if (targetPile.canAdd(card)) {
          validMoves.add(Move(
            type: MoveType.toWorkPile,
            playerId: playerId,
            cardId: card.id,
            targetPileIndex: i,
          ));
        }
      }
    }

    return validMoves;
  }

  static Move? getBestAutoMove(String cardId, String playerId, GameState gameState) {
    final player = gameState.getPlayer(playerId);
    if (player == null) return null;

    final location = player.findCard(cardId);
    if (location == null) return null;

    PlayingCard? card;
    bool isStackMove = false;

    switch (location.type) {
      case PileType.nertz:
        card = player.nertzPile.topCard;
        break;
      case PileType.waste:
        card = player.wastePile.topCard;
        break;
      case PileType.work:
        final pile = player.workPiles[location.pileIndex];
        if (location.cardIndex >= 0 && location.cardIndex < pile.length) {
          card = pile.cards[location.cardIndex];
          // If we are moving a card that is NOT the top card, it's a stack move
          if (location.cardIndex < pile.length - 1) {
            isStackMove = true;
          }
        }
        break;
      default:
        return null;
    }

    if (card == null || card.id != cardId) return null;

    // 1. Try Center Move (Only if top card)
    if (!isStackMove) {
      final centerPileIndex = gameState.findCenterPileFor(card);
      if (centerPileIndex >= 0) {
        return Move(
          type: MoveType.toCenter,
          playerId: playerId,
          cardId: cardId,
          targetSuit: card.suit,
          targetPileIndex: centerPileIndex, // CRITICAL FIX: Must provide index
        );
      }
    }

    // 2. Try Work Pile Move
    // For stack moves, we need to validate the stack sequence first
    if (isStackMove) {
      final pile = player.workPiles[location.pileIndex];
      final cardsToMove = pile.getCardsFrom(location.cardIndex);
      if (!_isValidSolitaireSequence(cardsToMove)) {
        return null; // Invalid stack, can't move
      }
    }

    for (var i = 0; i < 4; i++) {
      // Don't move to the same pile
      if (location.type == PileType.work && location.pileIndex == i) continue;

      if (player.workPiles[i].canAdd(card)) {
        return Move(
          type: isStackMove ? MoveType.moveStack : MoveType.toWorkPile,
          playerId: playerId,
          cardId: cardId,
          targetPileIndex: i,
        );
      }
    }

    return null;
  }
}
