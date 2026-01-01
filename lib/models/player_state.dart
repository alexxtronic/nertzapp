/// Player state model for Nertz Royale

library;

import 'card.dart';
import 'pile.dart';

/// Complete state for a single player
class PlayerState {
  final String id;
  final String displayName;
  final NertzPile nertzPile;
  final List<WorkPile> workPiles; // 4 work piles
  final StockPile stockPile;
  final WastePile wastePile;
  int scoreThisRound;
  int scoreTotal;
  bool isReady;
  bool isConnected;
  final String? avatarUrl;
  final int wins;
  final bool isBot;
  final int? playerColor; // Stored as ARGB int for JSON serialization
  final String? selectedCardBack;
  final DateTime? lastMoveTime;
  final DateTime? lastPlayableActionTime; // Tracks last play to work/center pile for shuffle timer
  final int totalXp; // Total cumulative XP for ranking

  PlayerState({
    required this.id,
    required this.displayName,
    required this.nertzPile,
    required this.workPiles,
    required this.stockPile,
    required this.wastePile,
    this.scoreThisRound = 0,
    this.scoreTotal = 0,
    this.isReady = false,
    this.isConnected = true,
    this.avatarUrl,
    this.wins = 0,
    this.isBot = false,
    this.playerColor,
    this.selectedCardBack,
    this.lastMoveTime,
    this.lastPlayableActionTime,
    this.totalXp = 0,
  });

  PlayerRank get rank {
    if (totalXp >= 150000) return PlayerRank.legend;
    if (totalXp >= 75000) return PlayerRank.grandmaster;
    if (totalXp >= 25000) return PlayerRank.master;
    if (totalXp >= 10000) return PlayerRank.diamond;
    if (totalXp >= 5000) return PlayerRank.platinum;
    if (totalXp >= 2500) return PlayerRank.gold;
    if (totalXp >= 1000) return PlayerRank.silver;
    return PlayerRank.bronze;
  }

  /// Create initial state from a shuffled deck
  factory PlayerState.fromDeck({
    required String id,
    required String displayName,
    required List<PlayingCard> shuffledDeck,
    String? avatarUrl,
    int wins = 0,
    bool isBot = false,
    String? selectedCardBack,
    int totalXp = 0,
  }) {
    assert(shuffledDeck.length == 52, 'Deck must have 52 cards');

    final nertzCards = shuffledDeck.sublist(0, 10).map((c) => c.copyWith(isNertzOrigin: true)).toList();
    final workCards = shuffledDeck.sublist(10, 14);
    final stockCards = shuffledDeck.sublist(14);

    return PlayerState(
      id: id,
      displayName: displayName,
      nertzPile: NertzPile.deal(nertzCards),
      workPiles: [
        WorkPile.withCard(workCards[0]),
        WorkPile.withCard(workCards[1]),
        WorkPile.withCard(workCards[2]),
        WorkPile.withCard(workCards[3]),
      ],
      stockPile: StockPile(stockCards),
      wastePile: WastePile(),
      avatarUrl: avatarUrl,
      wins: wins,
      isBot: isBot,
      playerColor: null, // Color assigned later by game logic
      selectedCardBack: selectedCardBack,
      totalXp: totalXp,
    );
  }

  /// Combine Stock and Waste, shuffle, and reset to Stock
  PlayerState resetStockAndWaste() {
    final allCards = [...stockPile.cards, ...wastePile.cards];
    allCards.shuffle(); 
    
    return copyWith(
      stockPile: StockPile(allCards),
      wastePile: WastePile(),
    );
  }

  bool get hasEmptiedNertz => nertzPile.isEmpty;

  int calculateRoundScore(int cardsPlayedToCenter) {
    final centerPoints = cardsPlayedToCenter;
    // New Scoring: +2 points for every Nertz card CLEARED
    // instead of -2 penalty for cards left.
    // Nertz pile starts with 10 cards.
    final cardsCleared = 10 - nertzPile.remaining;
    final nertzBonus = cardsCleared * 2;
    
    // New Penalty: -1 for every card left (increases stakes)
    final penalty = nertzPile.remaining;
    
    return centerPoints + nertzBonus - penalty;
  }

  List<PlayingCard> getPlayableCards() {
    final playable = <PlayingCard>[];
    if (nertzPile.topCard != null) playable.add(nertzPile.topCard!);
    if (wastePile.topCard != null) playable.add(wastePile.topCard!);
    for (final pile in workPiles) {
      if (pile.topCard != null) playable.add(pile.topCard!);
    }
    return playable;
  }

  void drawThree() {
    if (stockPile.isEmpty) {
      final wasteCards = wastePile.takeAll();
      if (wasteCards.isEmpty) return;
      stockPile.refill(wasteCards);
      return; // STOP: Refill is a separate action to prevent mixed cycles
    }
    final drawn = stockPile.draw(3);
    wastePile.addDrawn(drawn);
  }

  void drawOne() {
    if (stockPile.isEmpty) {
      final wasteCards = wastePile.takeAll();
      if (wasteCards.isEmpty) return;
      stockPile.refill(wasteCards);
      return; // STOP: Refill is a separate action to prevent mixed cycles
    }
    final drawn = stockPile.draw(1);
    wastePile.addDrawn(drawn);
  }

  PileLocation? findCard(String cardId) {
    if (nertzPile.topCard?.id == cardId) {
      return PileLocation(PileType.nertz, 0, nertzPile.cards.length - 1);
    }
    if (wastePile.topCard?.id == cardId) {
      return PileLocation(PileType.waste, 0, wastePile.cards.length - 1);
    }
    for (var i = 0; i < workPiles.length; i++) {
      final pile = workPiles[i];
      for (var j = 0; j < pile.cards.length; j++) {
        if (pile.cards[j].id == cardId) {
          return PileLocation(PileType.work, i, j);
        }
      }
    }
    return null;
  }

  PlayerState copyWith({
    String? id,
    String? displayName,
    NertzPile? nertzPile,
    List<WorkPile>? workPiles,
    StockPile? stockPile,
    WastePile? wastePile,
    int? scoreThisRound,
    int? scoreTotal,
    bool? isReady,
    bool? isConnected,
    String? avatarUrl,
    int? wins,
    bool? isBot,
    int? playerColor,
    String? selectedCardBack,
    DateTime? lastMoveTime,
    DateTime? lastPlayableActionTime,
    int? totalXp,
  }) {
    return PlayerState(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      nertzPile: nertzPile ?? this.nertzPile,
      workPiles: workPiles ?? this.workPiles,
      stockPile: stockPile ?? this.stockPile,
      wastePile: wastePile ?? this.wastePile,
      scoreThisRound: scoreThisRound ?? this.scoreThisRound,
      scoreTotal: scoreTotal ?? this.scoreTotal,
      isReady: isReady ?? this.isReady,
      isConnected: isConnected ?? this.isConnected,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      wins: wins ?? this.wins,
      isBot: isBot ?? this.isBot,
      playerColor: playerColor ?? this.playerColor,
      lastMoveTime: lastMoveTime ?? this.lastMoveTime,
      lastPlayableActionTime: lastPlayableActionTime ?? this.lastPlayableActionTime,
      selectedCardBack: selectedCardBack ?? this.selectedCardBack,
      totalXp: totalXp ?? this.totalXp,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'nertzPile': nertzPile.toJson(),
    'workPiles': workPiles.map((p) => p.toJson()).toList(),
    'stockPile': stockPile.toJson(),
    'wastePile': wastePile.toJson(),
    'scoreThisRound': scoreThisRound,
    'scoreTotal': scoreTotal,
    'isReady': isReady,
    'isConnected': isConnected,
    'avatarUrl': avatarUrl,
    'wins': wins,
    'isBot': isBot,
    'playerColor': playerColor,
    'lastMoveTime': lastMoveTime?.toIso8601String(),
    'lastPlayableActionTime': lastPlayableActionTime?.toIso8601String(),
    'selectedCardBack': selectedCardBack,
    'totalXp': totalXp,
  };

  factory PlayerState.fromJson(Map<String, dynamic> json) => PlayerState(
    id: json['id'] as String,
    displayName: json['displayName'] as String,
    nertzPile: NertzPile.fromJson(json['nertzPile']),
    workPiles: (json['workPiles'] as List).map((p) => WorkPile.fromJson(p)).toList(),
    stockPile: StockPile.fromJson(json['stockPile']),
    wastePile: WastePile.fromJson(json['wastePile']),
    scoreThisRound: json['scoreThisRound'] as int,
    scoreTotal: json['scoreTotal'] as int,
    isReady: json['isReady'] as bool,
    isConnected: json['isConnected'] as bool,
    avatarUrl: json['avatarUrl'] as String?,
    wins: json['wins'] as int? ?? 0,
    isBot: json['isBot'] as bool? ?? false,
    playerColor: json['playerColor'] as int?,
    lastMoveTime: json['lastMoveTime'] != null ? DateTime.parse(json['lastMoveTime']) : null,
    lastPlayableActionTime: json['lastPlayableActionTime'] != null ? DateTime.parse(json['lastPlayableActionTime']) : null,
    selectedCardBack: json['selectedCardBack'] as String?,
    totalXp: json['totalXp'] as int? ?? 0,
  );
}

enum PlayerRank { bronze, silver, gold, platinum, diamond, master, grandmaster, legend }

enum PileType { nertz, work, stock, waste, center }

class PileLocation {
  final PileType type;
  final int pileIndex;
  final int cardIndex;

  PileLocation(this.type, this.pileIndex, this.cardIndex);

  @override
  String toString() => 'PileLocation($type, pile: $pileIndex, card: $cardIndex)';

  Map<String, dynamic> toJson() => {
    'type': type.index,
    'pileIndex': pileIndex,
    'cardIndex': cardIndex,
  };

  factory PileLocation.fromJson(Map<String, dynamic> json) => PileLocation(
    PileType.values[json['type'] as int],
    json['pileIndex'] as int,
    json['cardIndex'] as int,
  );
}
