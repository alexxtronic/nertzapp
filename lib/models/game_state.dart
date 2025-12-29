/// Game state model for Nertz Royale

library;

import 'card.dart';
import 'pile.dart';
import 'player_state.dart';
import '../utils/player_colors.dart';

/// Current phase of the game
enum GamePhase {
  lobby,
  starting,
  playing,
  roundEnd,
  matchEnd,
}

/// Complete game state
class GameState {
  static const int maxPlayers = 4;
  
  final String matchId;
  final Map<String, PlayerState> players;
  final List<CenterPile> centerPiles; // 16 generic slots
  GamePhase phase;
  int roundNumber;
  int pointsToWin; // Mutable: can be set to 50, 100, or 150
  String? hostId;
  String? roundWinnerId;
  DateTime? roundStartTime;
  Set<String> resetVotes;

  GameState({
    required this.matchId,
    required this.players,
    required this.centerPiles,
    this.phase = GamePhase.lobby,
    this.roundNumber = 0,
    this.pointsToWin = 100,
    this.hostId,
    this.roundWinnerId,
    this.roundStartTime,
    this.resetVotes = const {},
  });
  
  bool get isFull => players.length >= maxPlayers;

  factory GameState.newMatch(String matchId, String hostId, String hostName) {
    final hostState = PlayerState(
      id: hostId,
      displayName: hostName,
      nertzPile: NertzPile([]),
      workPiles: [WorkPile(), WorkPile(), WorkPile(), WorkPile()],
      stockPile: StockPile([]),
      wastePile: WastePile(),
    );

    return GameState(
      matchId: matchId,
      players: {hostId: hostState},
      // 16 generic center pile slots
      centerPiles: List.generate(16, (_) => CenterPile()),
      hostId: hostId,
    );
  }

  void addPlayer(String playerId, String displayName, {bool isBot = false}) {
    if (phase != GamePhase.lobby) {
      throw StateError('Cannot add players during active game');
    }
    if (players.length >= maxPlayers) {
      throw StateError('Maximum $maxPlayers players allowed');
    }

    players[playerId] = PlayerState(
      id: playerId,
      displayName: displayName,
      nertzPile: NertzPile([]),
      workPiles: [WorkPile(), WorkPile(), WorkPile(), WorkPile()],
      stockPile: StockPile([]),
      wastePile: WastePile(),
      isBot: isBot,
    );
  }

  void removePlayer(String playerId) {
    players.remove(playerId);
    if (playerId == hostId && players.isNotEmpty) {
      hostId = players.keys.first;
    }
  }

  void startRound() {
    roundNumber++;
    roundWinnerId = null;
    roundStartTime = DateTime.now();
    
    // Clear all 16 center piles
    for (final pile in centerPiles) {
      pile.cards.clear();
    }

    for (final player in players.values) {
      final deck = Deck.createShuffled(player.id);
      
      // CRITICAL: Integrity Check
      if (deck.length != 52) {
        throw StateError('Invalid deck size: ${deck.length} cards generated for ${player.displayName}');
      }
      final uniqueIds = deck.map((c) => c.id).toSet();
      if (uniqueIds.length != 52) {
        throw StateError('Duplicate card IDs detected in deck for ${player.displayName}');
      }

      final newState = PlayerState.fromDeck(
        id: player.id,
        displayName: player.displayName,
        shuffledDeck: deck,
        isBot: player.isBot,
      );
      
      // Preserve player color and scoreTotal across rounds
      final updatedState = newState.copyWith(
        playerColor: player.playerColor, // Preserve color from previous round
      );
      updatedState.scoreTotal = player.scoreTotal; // Preserve total score
      players[player.id] = updatedState;
    }

    phase = GamePhase.playing;
    
    // Assign player colors if not already assigned (first round)
    _assignPlayerColors();
  }
  
  /// Assign random colors to players who don't have one yet
  void _assignPlayerColors() {
    final playerIds = players.keys.toList();
    final colorAssignments = PlayerColors.assignColors(playerIds);
    
    for (final playerId in playerIds) {
      final player = players[playerId]!;
      // Only assign if player doesn't have a color yet
      if (player.playerColor == null) {
        final assignedColor = colorAssignments[playerId]!;
        players[playerId] = player.copyWith(
          playerColor: PlayerColors.colorToInt(assignedColor),
        );
      }
    }
  }

  void voteForReset(String playerId) {
    if (players.containsKey(playerId)) {
      resetVotes.add(playerId);
    }
  }
  
  void clearResetVotes() {
    resetVotes.clear();
  }
  
  bool get hasUnanimousResetVote => 
      players.isNotEmpty && resetVotes.length == players.length;
  
  void executeReset() {
    for (final key in players.keys) {
      players[key] = players[key]!.resetStockAndWaste();
    }
    clearResetVotes();
  }

  /// Find a center pile that can accept this card
  /// Returns the pile index, or -1 if no pile can accept it
  int findCenterPileFor(PlayingCard card) {
    // First, try to find a pile that already has cards of this suit
    for (int i = 0; i < centerPiles.length; i++) {
      final pile = centerPiles[i];
      if (!pile.isEmpty && pile.suit == card.suit && pile.canAdd(card)) {
        return i;
      }
    }
    // If it's an Ace, find an empty slot
    if (card.rank == Rank.ace) {
      for (int i = 0; i < centerPiles.length; i++) {
        if (centerPiles[i].isEmpty) {
          return i;
        }
      }
    }
    return -1;
  }

  bool canPlayToCenter(PlayingCard card) {
    return findCenterPileFor(card) >= 0;
  }

  void playToCenter(PlayingCard card) {
    final pileIndex = findCenterPileFor(card);
    assert(pileIndex >= 0, 'No valid center pile for $card');
    centerPiles[pileIndex].push(card);
  }

  /// Play to a specific center pile (for targeted moves)
  void playToCenterPile(PlayingCard card, int pileIndex, {String? playerId}) {
    assert(pileIndex >= 0 && pileIndex < centerPiles.length);
    assert(centerPiles[pileIndex].canAdd(card));
    centerPiles[pileIndex].push(card, playerId: playerId);
  }

  int countPlayerCardsInCenter(String playerId) {
    int count = 0;
    for (final pile in centerPiles) {
      count += pile.cards.where((c) => c.ownerId == playerId).length;
    }
    return count;
  }

  void endRound(String winnerId) {
    roundWinnerId = winnerId;
    phase = GamePhase.roundEnd;

    for (final player in players.values) {
      final cardsInCenter = countPlayerCardsInCenter(player.id);
      player.scoreThisRound = player.calculateRoundScore(cardsInCenter);
      player.scoreTotal += player.scoreThisRound;
    }

    final winners = players.values.where((p) => p.scoreTotal >= pointsToWin);
    if (winners.isNotEmpty) {
      phase = GamePhase.matchEnd;
    }
  }

  PlayerState? get leader {
    if (players.isEmpty) return null;
    return players.values.reduce((a, b) => a.scoreTotal > b.scoreTotal ? a : b);
  }

  List<PlayerState> get leaderboard {
    final sorted = players.values.toList();
    sorted.sort((a, b) => b.scoreTotal.compareTo(a.scoreTotal));
    return sorted;
  }

  bool get allPlayersReady => 
    players.length >= 2 && players.values.every((p) => p.isReady);

  PlayerState? getPlayer(String id) => players[id];

  Map<String, dynamic> toJson() => {
    'matchId': matchId,
    'players': players.map((k, v) => MapEntry(k, v.toJson())),
    'centerPiles': centerPiles.map((pile) => pile.toJson()).toList(),
    'phase': phase.index,
    'roundNumber': roundNumber,
    'pointsToWin': pointsToWin,
    'hostId': hostId,
    'roundWinnerId': roundWinnerId,
    'roundWinnerId': roundWinnerId,
    'roundStartTime': roundStartTime?.toIso8601String(),
    'resetVotes': resetVotes.toList(),
  };

  factory GameState.fromJson(Map<String, dynamic> json) {
    final centerPilesJson = json['centerPiles'] as List<dynamic>;
    final centerPiles = centerPilesJson
        .map((pile) => CenterPile.fromJson(pile as Map<String, dynamic>))
        .toList();

    return GameState(
      matchId: json['matchId'] as String,
      players: (json['players'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, PlayerState.fromJson(v)),
      ),
      centerPiles: centerPiles,
      phase: GamePhase.values[json['phase'] as int],
      roundNumber: json['roundNumber'] as int,
      pointsToWin: json['pointsToWin'] as int? ?? 100,
      hostId: json['hostId'] as String?,
      roundWinnerId: json['roundWinnerId'] as String?,
      roundStartTime: json['roundStartTime'] != null 
        ? DateTime.parse(json['roundStartTime']) 
        : null,
      resetVotes: (json['resetVotes'] as List?)?.map((e) => e as String).toSet() ?? {},
    );
  }
}
