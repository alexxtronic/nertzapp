/// Pile models for Nertz Royale

library;

import 'card.dart';

/// Base class for all pile types
abstract class Pile {
  List<PlayingCard> get cards;
  
  bool get isEmpty => cards.isEmpty;
  bool get isNotEmpty => cards.isNotEmpty;
  int get length => cards.length;
  
  PlayingCard? get topCard => cards.isEmpty ? null : cards.last;
  
  Map<String, dynamic> toJson();
}

/// The Nertz pile - 10 cards, only top card is face-up during play
class NertzPile extends Pile {
  @override
  final List<PlayingCard> cards;
  
  NertzPile(this.cards);
  
  /// Create from a list of 10 cards (dealt from deck)
  factory NertzPile.deal(List<PlayingCard> dealtCards) {
    assert(dealtCards.length == 10, 'Nertz pile must have exactly 10 cards');
    return NertzPile(List.from(dealtCards));
  }
  
  /// Remove and return the top card
  PlayingCard? pop() {
    if (cards.isEmpty) return null;
    return cards.removeLast();
  }
  
  /// Number of cards remaining (for scoring: -2 per card)
  int get remaining => cards.length;
  
  @override
  Map<String, dynamic> toJson() => {
    'type': 'nertz',
    'cards': cards.map((c) => c.toJson()).toList(),
  };
  
  factory NertzPile.fromJson(Map<String, dynamic> json) => NertzPile(
    (json['cards'] as List).map((c) => PlayingCard.fromJson(c)).toList(),
  );
}

/// Work pile - tableau-style building, all cards visible
class WorkPile extends Pile {
  @override
  final List<PlayingCard> cards;
  
  WorkPile([List<PlayingCard>? initialCards]) : cards = initialCards ?? [];
  
  /// Create with a single initial card
  factory WorkPile.withCard(PlayingCard card) => WorkPile([card]);
  
  /// Check if a card can be added to this pile
  bool canAdd(PlayingCard card) => card.canPlaceOnWorkPile(topCard);
  
  /// Add a card to the pile
  void push(PlayingCard card) {
    assert(canAdd(card), 'Invalid move: $card cannot be placed on ${topCard?.display ?? "empty pile"}');
    cards.add(card);
  }
  
  /// Remove and return the top card
  PlayingCard? pop() {
    if (cards.isEmpty) return null;
    return cards.removeLast();
  }
  
  /// Get a range of cards from the pile (for multi-card moves)
  List<PlayingCard> getCardsFrom(int startIndex) {
    if (startIndex < 0 || startIndex >= cards.length) return [];
    return cards.sublist(startIndex);
  }
  
  /// Remove cards from startIndex onwards and return them
  List<PlayingCard> removeCardsFrom(int startIndex) {
    if (startIndex < 0 || startIndex >= cards.length) return [];
    final removed = cards.sublist(startIndex);
    cards.removeRange(startIndex, cards.length);
    return removed;
  }
  
  /// Add multiple cards (for multi-card moves)
  void pushAll(List<PlayingCard> cardsToAdd) {
    for (final card in cardsToAdd) {
      push(card);
    }
  }
  
  @override
  Map<String, dynamic> toJson() => {
    'type': 'work',
    'cards': cards.map((c) => c.toJson()).toList(),
  };
  
  factory WorkPile.fromJson(Map<String, dynamic> json) => WorkPile(
    (json['cards'] as List).map((c) => PlayingCard.fromJson(c)).toList(),
  );
}

/// Stock pile - face-down draw pile
class StockPile extends Pile {
  @override
  final List<PlayingCard> cards;
  
  StockPile(this.cards);
  
  /// Draw cards from the stock (up to 3, or remaining if less)
  List<PlayingCard> draw([int count = 3]) {
    final toDraw = count.clamp(0, cards.length);
    final drawn = <PlayingCard>[];
    
    for (var i = 0; i < toDraw; i++) {
      drawn.add(cards.removeLast());
    }
    
    return drawn;
  }
  
  /// Refill the stock from waste pile cards (preserving order)
  void refill(List<PlayingCard> wasteCards) {
    // wasteCards are in the order they were drawn (top of waste is last in list)
    // To restore stock order, we reverse them so the first card drawn becomes the last card in stock
    cards.clear();
    cards.addAll(wasteCards.reversed);
  }
  
  @override
  Map<String, dynamic> toJson() => {
    'type': 'stock',
    'cards': cards.map((c) => c.toJson()).toList(),
  };
  
  factory StockPile.fromJson(Map<String, dynamic> json) => StockPile(
    (json['cards'] as List).map((c) => PlayingCard.fromJson(c)).toList(),
  );
}

/// Waste pile - face-up pile from stock flips
class WastePile extends Pile {
  @override
  final List<PlayingCard> cards;
  
  WastePile([List<PlayingCard>? initialCards]) : cards = initialCards ?? [];
  
  /// Add cards drawn from stock
  void addDrawn(List<PlayingCard> drawnCards) {
    cards.addAll(drawnCards);
  }
  
  /// Remove and return the top card (for playing to work/center)
  PlayingCard? pop() {
    if (cards.isEmpty) return null;
    return cards.removeLast();
  }
  
  /// Get all cards (for recycling into stock)
  List<PlayingCard> takeAll() {
    final all = List<PlayingCard>.from(cards);
    cards.clear();
    return all;
  }
  
  @override
  Map<String, dynamic> toJson() => {
    'type': 'waste',
    'cards': cards.map((c) => c.toJson()).toList(),
  };
  
  factory WastePile.fromJson(Map<String, dynamic> json) => WastePile(
    (json['cards'] as List).map((c) => PlayingCard.fromJson(c)).toList(),
  );
}

class CenterPile extends Pile {
  @override
  final List<PlayingCard> cards;
  
  /// Track which player placed the last card (for color glow)
  String? lastPlayerId;
  
  /// Track when the last card was placed (for glow fade animation)
  DateTime? lastPlacedTime;
  
  CenterPile({
    List<PlayingCard>? initialCards,
    this.lastPlayerId,
    this.lastPlacedTime,
  }) : cards = initialCards ?? [];
  
  /// The suit of this pile (determined by the first card)
  Suit? get suit => cards.isEmpty ? null : cards.first.suit;
  
  /// Check if a card can be added to this pile
  bool canAdd(PlayingCard card) {
    // Empty pile: only Aces can start
    if (cards.isEmpty) {
      return card.rank == Rank.ace;
    }
    // Non-empty: must match suit and be next in sequence
    if (card.suit != suit) return false;
    return card.canPlaceOnCenterPile(cards);
  }
  
  /// Add a card to the pile
  void push(PlayingCard card, {String? playerId}) {
    assert(canAdd(card), 'Invalid move: $card cannot be placed on center pile');
    cards.add(card);
    lastPlayerId = playerId;
    lastPlacedTime = DateTime.now();
  }
  
  /// Check if the pile is complete (has all 13 cards)
  bool get isComplete => cards.length == 13;
  
  /// Get the expected next rank
  Rank? get nextExpectedRank {
    if (cards.isEmpty) return Rank.ace;
    final topRank = cards.last.rank;
    return topRank.next;
  }
  
  @override
  Map<String, dynamic> toJson() => {
    'type': 'center',
    'cards': cards.map((c) => c.toJson()).toList(),
    'lastPlayerId': lastPlayerId,
    'lastPlacedTime': lastPlacedTime?.toIso8601String(),
  };
  
  factory CenterPile.fromJson(Map<String, dynamic> json) => CenterPile(
    initialCards: (json['cards'] as List).map((c) => PlayingCard.fromJson(c)).toList(),
    lastPlayerId: json['lastPlayerId'] as String?,
    lastPlacedTime: json['lastPlacedTime'] != null 
        ? DateTime.parse(json['lastPlacedTime'] as String)
        : null,
  );
}
