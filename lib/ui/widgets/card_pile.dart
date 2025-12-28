/// Card pile widgets for Nertz Royale

library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/card.dart';
import '../theme/game_theme.dart';
import 'playing_card.dart';

/// A stacked pile of cards (for work piles)
class StackedCardPile extends StatelessWidget {
  final List<PlayingCard> cards;
  final CardStyle style;
  final bool isValidTarget;
  final Function(PlayingCard)? onCardTap;
  final Function(PlayingCard)? onCardDoubleTap;
  final Function(PlayingCard)? onAcceptCard;
  
  const StackedCardPile({
    super.key,
    required this.cards,
    this.style = CardStyle.normal,
    this.isValidTarget = false,
    this.onCardTap,
    this.onCardDoubleTap,
    this.onAcceptCard,
  });

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return DragTarget<PlayingCard>(
        onWillAcceptWithDetails: (details) => isValidTarget,
        onAcceptWithDetails: (details) {
          HapticFeedback.mediumImpact();
          onAcceptCard?.call(details.data);
        },
        builder: (context, candidateData, rejectedData) {
          return CardSlot(
            isValidTarget: candidateData.isNotEmpty,
          );
        },
      );
    }
    
    return DragTarget<PlayingCard>(
      onWillAcceptWithDetails: (details) => isValidTarget,
      onAcceptWithDetails: (details) {
        HapticFeedback.mediumImpact();
        onAcceptCard?.call(details.data);
      },
      builder: (context, candidateData, rejectedData) {
        final stackHeight = GameTheme.cardHeight + 
            (cards.length - 1) * GameTheme.cardStackOffset;
        
        return SizedBox(
          width: GameTheme.cardWidth,
          height: stackHeight,
          child: Stack(
            children: [
              for (int i = 0; i < cards.length; i++)
                Positioned(
                  top: i * GameTheme.cardStackOffset,
                  child: DraggableCard(
                    card: cards[i],
                    faceUp: true,
                    canDrag: i == cards.length - 1,
                    style: style,
                    onTap: () => onCardTap?.call(cards[i]),
                    onDoubleTap: () => onCardDoubleTap?.call(cards[i]),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Stock pile widget (face-down draw pile)
class StockPileWidget extends StatelessWidget {
  final int cardCount;
  final VoidCallback? onTap;
  
  const StockPileWidget({
    super.key,
    required this.cardCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (cardCount == 0) {
      return GestureDetector(
        onTap: onTap,
        child: CardSlot(
          label: '↻',
          onTap: onTap,
        ),
      );
    }
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: Stack(
        children: [
          for (int i = 0; i < (cardCount > 3 ? 3 : cardCount); i++)
            Positioned(
              top: i * 2.0,
              left: i * 1.0,
              child: Container(
                width: GameTheme.cardWidth,
                height: GameTheme.cardHeight,
                decoration: BoxDecoration(
                  gradient: GameTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(GameTheme.cardRadius),
                  border: Border.all(color: GameTheme.cardBorder),
                  boxShadow: GameTheme.cardShadow,
                ),
                child: Center(
                  child: Container(
                    width: GameTheme.cardWidth - 16,
                    height: GameTheme.cardHeight - 16,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white30, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        'N',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Waste pile widget (face-up from stock)
class WastePileWidget extends StatelessWidget {
  final List<PlayingCard> cards;
  final CardStyle style;
  final Function(PlayingCard)? onCardTap;
  final Function(PlayingCard)? onCardDoubleTap;
  
  const WastePileWidget({
    super.key,
    required this.cards,
    this.style = CardStyle.normal,
    this.onCardTap,
    this.onCardDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return const CardSlot();
    }
    
    final visibleCards = cards.length > 3 
        ? cards.sublist(cards.length - 3) 
        : cards;
    
    return SizedBox(
      width: GameTheme.cardWidth + 20,
      height: GameTheme.cardHeight,
      child: Stack(
        children: [
          for (int i = 0; i < visibleCards.length; i++)
            Positioned(
              left: i * 10.0,
              child: i == visibleCards.length - 1
                  ? DraggableCard(
                      card: visibleCards[i],
                      faceUp: true,
                      style: style,
                      onTap: () => onCardTap?.call(visibleCards[i]),
                      onDoubleTap: () => onCardDoubleTap?.call(visibleCards[i]),
                    )
                  : PlayingCardWidget(
                      card: visibleCards[i],
                      faceUp: true,
                      isDraggable: false,
                      style: style,
                    ),
            ),
        ],
      ),
    );
  }
}

/// Nertz pile widget
class NertzPileWidget extends StatelessWidget {
  final List<PlayingCard> cards;
  final CardStyle style;
  final Function(PlayingCard)? onCardTap;
  final Function(PlayingCard)? onCardDoubleTap;
  
  const NertzPileWidget({
    super.key,
    required this.cards,
    this.style = CardStyle.normal,
    this.onCardTap,
    this.onCardDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return Container(
        width: GameTheme.cardWidth,
        height: GameTheme.cardHeight,
        decoration: BoxDecoration(
          color: GameTheme.success.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(GameTheme.cardRadius),
          border: Border.all(color: GameTheme.success, width: 2),
        ),
        child: const Center(
          child: Icon(
            Icons.check_circle,
            color: GameTheme.success,
            size: 32,
          ),
        ),
      );
    }
    
    return Stack(
      children: [
        for (int i = 0; i < (cards.length > 3 ? 3 : cards.length - 1); i++)
          Positioned(
            top: i * 2.0,
            left: i * 1.0,
            child: Container(
              width: GameTheme.cardWidth,
              height: GameTheme.cardHeight,
              decoration: BoxDecoration(
                gradient: GameTheme.primaryGradient,
                borderRadius: BorderRadius.circular(GameTheme.cardRadius),
                boxShadow: GameTheme.cardShadow,
              ),
            ),
          ),
        Positioned(
          top: ((cards.length > 3 ? 3 : cards.length - 1) * 2.0),
          left: ((cards.length > 3 ? 3 : cards.length - 1) * 1.0),
          child: DraggableCard(
            card: cards.last,
            faceUp: true,
            style: style,
            onTap: () => onCardTap?.call(cards.last),
            onDoubleTap: () => onCardDoubleTap?.call(cards.last),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: cards.length <= 3 
                  ? GameTheme.warning 
                  : GameTheme.surface.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${cards.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Center pile widget
class CenterPileWidget extends StatelessWidget {
  final Suit suit;
  final List<PlayingCard> cards;
  final bool isValidTarget;
  final Function(PlayingCard)? onAcceptCard;
  
  const CenterPileWidget({
    super.key,
    required this.suit,
    required this.cards,
    this.isValidTarget = false,
    this.onAcceptCard,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<PlayingCard>(
      onWillAcceptWithDetails: (details) => 
          details.data.suit == suit && isValidTarget,
      onAcceptWithDetails: (details) {
        HapticFeedback.heavyImpact();
        onAcceptCard?.call(details.data);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        
        if (cards.isEmpty) {
          return AnimatedContainer(
            duration: GameTheme.cardHighlightDuration,
            width: GameTheme.cardWidth,
            height: GameTheme.cardHeight,
            decoration: BoxDecoration(
              color: isHovering
                  ? GameTheme.success.withValues(alpha: 0.3)
                  : GameTheme.surfaceLight.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(GameTheme.cardRadius),
              border: Border.all(
                color: isHovering ? GameTheme.success : GameTheme.surfaceLight,
                width: isHovering ? 2 : 1,
              ),
            ),
            child: Center(
              child: Text(
                suit.symbol,
                style: TextStyle(
                  fontSize: 32,
                  color: suit.color == CardColor.red
                      ? GameTheme.cardRed.withValues(alpha: 0.5)
                      : GameTheme.cardBlack.withValues(alpha: 0.5),
                ),
              ),
            ),
          );
        }
        
        return AnimatedContainer(
          duration: GameTheme.cardHighlightDuration,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GameTheme.cardRadius),
            boxShadow: isHovering ? GameTheme.cardHoverShadow : null,
          ),
          child: PlayingCardWidget(
            card: cards.last,
            faceUp: true,
            isDraggable: false,
            isHighlighted: isHovering,
          ),
        );
      },
    );
  }
}
