/// Card models for Nertz Royale

library;

import 'package:uuid/uuid.dart';

/// The four standard card suits
enum Suit {
  hearts('♥', 'Hearts', CardColor.red),
  diamonds('♦', 'Diamonds', CardColor.red),
  clubs('♣', 'Clubs', CardColor.black),
  spades('♠', 'Spades', CardColor.black);

  final String symbol;
  final String name;
  final CardColor color;

  const Suit(this.symbol, this.name, this.color);

  /// Color-blind friendly shape for accessibility
  String get accessibilityShape {
    switch (this) {
      case Suit.hearts:
        return '❤'; // Filled heart
      case Suit.diamonds:
        return '◆'; // Filled diamond
      case Suit.clubs:
        return '♣'; // Club with stem
      case Suit.spades:
        return '♠'; // Spade with stem
    }
  }
}

/// Card colors (derived from suit)
enum CardColor {
  red,
  black;

  /// Returns the opposite color for alternating sequence validation
  CardColor get opposite => this == red ? black : red;
}

/// Card ranks from Ace (1) to King (13)
enum Rank {
  ace(1, 'A', 'Ace'),
  two(2, '2', 'Two'),
  three(3, '3', 'Three'),
  four(4, '4', 'Four'),
  five(5, '5', 'Five'),
  six(6, '6', 'Six'),
  seven(7, '7', 'Seven'),
  eight(8, '8', 'Eight'),
  nine(9, '9', 'Nine'),
  ten(10, '10', 'Ten'),
  jack(11, 'J', 'Jack'),
  queen(12, 'Q', 'Queen'),
  king(13, 'K', 'King');

  final int value;
  final String symbol;
  final String name;

  const Rank(this.value, this.symbol, this.name);

  /// Get the next rank (for center pile building)
  Rank? get next {
    if (value >= 13) return null;
    return Rank.values[value]; // value is 1-indexed, list is 0-indexed
  }

  /// Get the previous rank (for work pile building)
  Rank? get previous {
    if (value <= 1) return null;
    return Rank.values[value - 2];
  }
}

/// A playing card with suit, rank, and unique identifier
class PlayingCard {
  final String id;
  final Suit suit;
  final Rank rank;
  final String ownerId; // Which player's deck this card belongs to

  PlayingCard({
    required this.id,
    required this.suit,
    required this.rank,
    required this.ownerId,
  });

  /// Derived color from suit
  CardColor get color => suit.color;

  /// Display string like "A♥" or "10♠"
  String get display => '${rank.symbol}${suit.symbol}';

  /// Full name like "Ace of Hearts"
  String get fullName => '${rank.name} of ${suit.name}';

  /// Check if this card can be placed on another card in work piles
  /// Rules: descending rank, alternating colors
  bool canPlaceOnWorkPile(PlayingCard? targetCard) {
    if (targetCard == null) {
      // Empty pile - any card can start
      return true;
    }
    
    // Must be one rank lower and opposite color
    return rank.value == targetCard.rank.value - 1 &&
           color != targetCard.color;
  }

  /// Check if this card can be placed on a center pile
  /// Rules: ascending rank, same suit
  bool canPlaceOnCenterPile(List<PlayingCard> centerPile) {
    if (centerPile.isEmpty) {
      // Only Ace can start a center pile
      return rank == Rank.ace;
    }
    
    final topCard = centerPile.last;
    // Must be same suit and next rank
    return suit == topCard.suit && rank.value == topCard.rank.value + 1;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayingCard &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'PlayingCard($display, owner: $ownerId)';

  /// Create a copy with optional overrides
  PlayingCard copyWith({
    String? id,
    Suit? suit,
    Rank? rank,
    String? ownerId,
  }) {
    return PlayingCard(
      id: id ?? this.id,
      suit: suit ?? this.suit,
      rank: rank ?? this.rank,
      ownerId: ownerId ?? this.ownerId,
    );
  }

  /// Convert to JSON for network transmission
  Map<String, dynamic> toJson() => {
    'id': id,
    'suit': suit.index,
    'rank': rank.index,
    'ownerId': ownerId,
  };

  /// Create from JSON
  factory PlayingCard.fromJson(Map<String, dynamic> json) => PlayingCard(
    id: json['id'] as String,
    suit: Suit.values[json['suit'] as int],
    rank: Rank.values[json['rank'] as int],
    ownerId: json['ownerId'] as String,
  );
}

/// Factory for creating decks of cards
class Deck {
  static final _uuid = Uuid();

  /// Create a standard 52-card deck for a player
  static List<PlayingCard> create(String ownerId) {
    final cards = <PlayingCard>[];
    
    for (final suit in Suit.values) {
      for (final rank in Rank.values) {
        cards.add(PlayingCard(
          id: _uuid.v4(),
          suit: suit,
          rank: rank,
          ownerId: ownerId,
        ));
      }
    }
    
    return cards;
  }

  /// Create and shuffle a deck
  static List<PlayingCard> createShuffled(String ownerId) {
    final cards = create(ownerId);
    cards.shuffle();
    return cards;
  }
}
