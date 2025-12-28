/// Game board widget for Nertz Royale

library;

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../models/card.dart';
import '../../models/game_state.dart';
import '../../models/player_state.dart';
import '../../models/pile.dart';
import '../../engine/move_validator.dart';
import '../theme/game_theme.dart';

/// Glassy, rounded card for the new aesthetic
class GlassCard extends StatelessWidget {
  final PlayingCard card;
  final bool faceUp;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final double scale;
  
  const GlassCard({
    super.key,
    required this.card,
    this.faceUp = true,
    this.onTap,
    this.onDoubleTap,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: GameTheme.cardWidth,
          height: GameTheme.cardHeight,
          decoration: BoxDecoration(
            color: faceUp ? Colors.white : Colors.white,
            borderRadius: BorderRadius.circular(GameTheme.cardRadius),
            boxShadow: GameTheme.cardShadow,
            gradient: faceUp 
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, Color(0xFFF8FAFC)],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [GameTheme.secondary, GameTheme.primary],
                ),
          ),
          child: faceUp ? _buildFace() : _buildBack(),
        ),
      ),
    );
  }

  Widget _buildFace() {
    final color = card.color == CardColor.red ? GameTheme.cardRed : GameTheme.cardBlack;
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            card.rank.symbol,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'SF Pro Rounded',
              height: 1.0,
            ),
          ),
          Text(
            card.suit.symbol,
            style: TextStyle(
              color: color,
              fontSize: 12,
              height: 1.0,
            ),
          ),
          const Spacer(),
          Align(
            alignment: Alignment.bottomRight,
            child: Transform.rotate(
              angle: math.pi,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    card.rank.symbol,
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'SF Pro Rounded',
                      height: 1.0,
                    ),
                  ),
                  Text(
                    card.suit.symbol,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBack() {
    return Center(
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            'N',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

/// Ghostly placeholder for empty slots
class GhostSlot extends StatelessWidget {
  final String? label;
  final VoidCallback? onTap;
  
  const GhostSlot({super.key, this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: GameTheme.cardWidth,
        height: GameTheme.cardHeight,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(GameTheme.cardRadius),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: label != null
            ? Center(
                child: Text(
                  label!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

/// The main game board layout
class GameBoard extends StatefulWidget {
  final GameState gameState;
  final String currentPlayerId;
  final CardStyle style;
  final Function(Move)? onMove;
  final Function(PlayingCard)? onCardDoubleTap;
  final VoidCallback? onCenterPilePlaced;
  
  const GameBoard({
    super.key,
    required this.gameState,
    required this.currentPlayerId,
    this.style = CardStyle.normal,
    this.onMove,
    this.onCardDoubleTap,
    this.onCenterPilePlaced,
  });

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> with TickerProviderStateMixin {
  bool _isDrawing = false;
  
  // Animation state for waste pile
  int _visibleWasteCards = 3; // How many of the last drawn cards to show
  int _previousWasteCount = 0; // Track waste pile count for animation
  List<Timer> _cardRevealTimers = [];
  
  GameState get gameState => widget.gameState;
  String get currentPlayerId => widget.currentPlayerId;
  Function(Move)? get onMove => widget.onMove;
  VoidCallback? get onCenterPilePlaced => widget.onCenterPilePlaced;

  PlayerState? get currentPlayer => gameState.getPlayer(currentPlayerId);
  
  List<PlayerState> get opponents => gameState.players.values
      .where((p) => p.id != currentPlayerId)
      .toList();
  
  @override
  void dispose() {
    for (final timer in _cardRevealTimers) {
      timer.cancel();
    }
    super.dispose();
  }
  
  /// Draw up to 3 cards from stock to waste with staggered animation
  void _drawFromStock() {
    if (_isDrawing) return;
    _isDrawing = true;

    final player = currentPlayer;
    if (player == null) {
      _isDrawing = false;
      return;
    }

    // If stock is empty, do nothing (Reset button handles this)
    if (player.stockPile.isEmpty) {
      _isDrawing = false;
      return;
    }

    // Cancel any existing timers
    for (final timer in _cardRevealTimers) {
      timer.cancel();
    }
    _cardRevealTimers.clear();
    
    // Calculate how many cards will be drawn (up to 3, or remaining)
    final cardsToDraw = player.stockPile.length.clamp(1, 3);
    
    // Start with 0 visible cards
    setState(() {
      _visibleWasteCards = 0;
      _previousWasteCount = player.wastePile.length;
    });

    // Execute the draw move first
    onMove?.call(Move(
      type: MoveType.drawThree,
      playerId: currentPlayerId,
    ));
    
    // Animate cards appearing one at a time at 0.25s intervals
    for (int i = 0; i < cardsToDraw; i++) {
      final timer = Timer(Duration(milliseconds: 250 * (i + 1)), () {
        if (mounted) {
          setState(() {
            _visibleWasteCards = i + 1;
          });
        }
      });
      _cardRevealTimers.add(timer);
    }
    
    // Allow next draw after animation completes
    Timer(Duration(milliseconds: 250 * cardsToDraw + 50), () {
      _isDrawing = false;
    });
  }

  /// Reset the stock pile from waste
  void _resetStock() {
    final player = currentPlayer;
    if (player == null) return;
    if (!player.stockPile.isEmpty) return; // Only reset if empty
    if (player.wastePile.isEmpty) return;  // Nothing to reset

    // drawThree when stock is empty will trigger refill in PlayerState
    onMove?.call(Move(
      type: MoveType.drawThree,
      playerId: currentPlayerId,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final player = currentPlayer;
    if (player == null) {
      return const Center(child: Text('Loading...'));
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: GameTheme.backgroundGradient,
      ),
      child: SafeArea(
        child: LayoutBuilder(
            builder: (context, constraints) {
            // Use CustomScrollView with SliverFillRemaining to allow Spacer() to work
            // while still being scrollable on small screens.
            return CustomScrollView(
              physics: const ClampingScrollPhysics(),
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    children: [
                      _buildHeader(player),
                      const SizedBox(height: 12), // Fixed small gap
                      _buildCenterArea(),
                      const SizedBox(height: 8), // Reduced to shift work piles up
                      _buildWorkPiles(context, player),
                      const SizedBox(height: 24), // Space between Work and Hand
                      _buildPlayerHand(player),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(PlayerState player) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NERTZ',
                style: TextStyle(
                  color: GameTheme.textPrimary.withValues(alpha: 0.4),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const Text(
                'ROYALE',
                style: TextStyle(
                  color: GameTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          
          Expanded(child: Container()),
          
          // Glass Pill (Score & Timer)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: GameTheme.pillGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: GameTheme.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  '${gameState.countPlayerCardsInCenter(currentPlayerId)} pts',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(child: Container()),

          // Avatars (simplified)
          ...opponents.take(3).map((opp) => Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white,
                  child: Text(
                    opp.displayName[0],
                    style: const TextStyle(
                      color: GameTheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  opp.displayName,
                  style: TextStyle(
                    color: GameTheme.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildCenterArea() {
    // 5% larger than before (was 84%, now 89% of normal)
    const double miniCardWidth = GameTheme.cardWidth * 0.89;
    const double miniCardHeight = GameTheme.cardHeight * 0.89;
    
    // Circular layout for 16 cards
    // Positions arranged in concentric arcs
    return Column(
      children: [
        // Shift down by card height
        SizedBox(height: GameTheme.cardHeight * 0.3),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Text(
                'CENTER PILES',
                style: TextStyle(
                  color: GameTheme.textSecondary.withValues(alpha: 0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Text(
                '${gameState.centerPiles.where((p) => !p.isEmpty).length}/16',
                style: TextStyle(
                  color: GameTheme.textSecondary.withValues(alpha: 0.6),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Simple 4x4 grid layout (4 rows of 4 cards)
        for (int row = 0; row < 4; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (col) {
                final index = row * 4 + col;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _buildCenterPileSlot(index, miniCardWidth, miniCardHeight),
                );
              }),
            ),
          ),
      ],
    );
  }

  Widget _buildMiniCard(PlayingCard card, double width, double height) {
    final color = card.color == CardColor.red ? GameTheme.cardRed : GameTheme.cardBlack;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              card.rank.symbol,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              card.suit.symbol,
              style: TextStyle(
                color: color,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterPileSlot(int index, double width, double height) {
    final pile = gameState.centerPiles[index];
    return DragTarget<PlayingCard>(
      onWillAcceptWithDetails: (details) {
        return pile.canAdd(details.data);
      },
      onAcceptWithDetails: (details) {
        onMove?.call(Move(
          type: MoveType.toCenter,
          playerId: currentPlayerId,
          cardId: details.data.id,
          targetPileIndex: index,
        ));
        onCenterPilePlaced?.call(); // Trigger +1 animation
      },
      builder: (context, candidateData, rejectedData) {
        final isHighlighted = candidateData.isNotEmpty;
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: isHighlighted 
              ? GameTheme.success.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isHighlighted 
                ? GameTheme.success 
                : Colors.white.withValues(alpha: 0.2),
              width: isHighlighted ? 2 : 1,
            ),
          ),
          child: pile.isEmpty
            ? Center(
                child: Text(
                  'A',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : _buildMiniCard(pile.cards.last, width, height),
        );
      },
    );
  }

  Widget _buildPlayerHand(PlayerState player) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Nertz Pile (Far Left)
          Column(
            children: [
              player.nertzPile.isEmpty
                ? const GhostSlot(label: "WIN")
                : Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Draggable<PlayingCard>(
                        data: player.nertzPile.cards.last,
                        feedback: Material(
                          color: Colors.transparent,
                          child: Transform.scale(
                            scale: 1.1,
                            child: GlassCard(card: player.nertzPile.cards.last),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.3,
                          child: GlassCard(card: player.nertzPile.cards.last),
                        ),
                        child: GlassCard(card: player.nertzPile.cards.last),
                      ),
                      Positioned(
                        bottom: -10,
                        right: -10,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: GameTheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: GameTheme.softShadow,
                          ),
                          child: Center(
                            child: Text(
                              '${player.nertzPile.remaining}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              const SizedBox(height: 8),
              const Text("NERTZ", style: TextStyle(
                color: GameTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold
              )),
            ],
          ),
          
          // Waste + Stock (Right side: Waste left of Stock)
          Row(
            children: [
              // Waste (left of Stock) - shows up to 3 cards fanned with animation
              Column(
                children: [
                  _buildAnimatedWastePile(player),
                ],
              ),
                  const SizedBox(width: 12),
              // Stock (Far Right)
              Column(
                children: [
                  GestureDetector(
                    onTap: player.stockPile.isEmpty ? null : _drawFromStock,
                    behavior: HitTestBehavior.opaque,
                    child: player.stockPile.isEmpty
                      ? const GhostSlot(label: "")
                      : Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: GameTheme.cardWidth * 1.1,
                              height: GameTheme.cardHeight * 1.1,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(GameTheme.cardRadius),
                                boxShadow: GameTheme.softShadow,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(GameTheme.cardRadius),
                                child: Image.asset(
                                  'assets/card_back.png',
                                  width: GameTheme.cardWidth * 1.1,
                                  height: GameTheme.cardHeight * 1.1,
                                  fit: BoxFit.fill,
                                  errorBuilder: (context, error, stackTrace) {
                                    // Fallback if image doesn't load
                                    return Container(
                                      decoration: BoxDecoration(
                                        gradient: GameTheme.primaryGradient,
                                        borderRadius: BorderRadius.circular(GameTheme.cardRadius),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          'N',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            // Card count badge
                            Positioned(
                              bottom: -6,
                              right: -6,
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: GameTheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: Center(
                                  child: Text(
                                    '${player.stockPile.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                  ),
                  // Reset Deck button (only when stock is empty and waste has cards)
                  if (player.stockPile.isEmpty && !player.wastePile.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: ElevatedButton(
                        onPressed: _resetStock,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GameTheme.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('RESET', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    )
                  else
                    const SizedBox(height: 8),
                  const Text("STOCK", style: TextStyle(
                    color: GameTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold
                  )),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildWorkPiles(BuildContext context, PlayerState player) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(4, (pileIndex) {
          final pile = player.workPiles[pileIndex];
          return DragTarget<PlayingCard>(
            onWillAcceptWithDetails: (details) {
              return pile.canAdd(details.data);
            },
            onAcceptWithDetails: (details) {
              final movingCard = details.data;
              final location = player.findCard(movingCard.id);
              MoveType type = MoveType.toWorkPile;
              
              // Check if this is a stack move (dragging a card that isn't the top card)
              if (location != null && location.type == PileType.work) {
                 final sourcePile = player.workPiles[location.pileIndex];
                 if (location.cardIndex < sourcePile.length - 1) {
                     type = MoveType.moveStack;
                 }
              }

              onMove?.call(Move(
                type: type,
                playerId: currentPlayerId,
                cardId: details.data.id,
                targetPileIndex: pileIndex,
              ));
            },
            builder: (context, candidateData, rejectedData) {
              final isHighlighted = candidateData.isNotEmpty;
              return Container(
                decoration: isHighlighted ? BoxDecoration(
                  borderRadius: BorderRadius.circular(GameTheme.cardRadius),
                  boxShadow: [
                    BoxShadow(
                      color: GameTheme.success.withValues(alpha: 0.5),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ) : null,
                child: _buildWorkPileItem(pile, pileIndex),
              );
            },
          );
        }),
      ),
    );
  }

  Widget _buildWorkPileItem(WorkPile pile, int pileIndex) {
    if (pile.isEmpty) {
      return const GhostSlot();
    }
    
    // Calculate offset based on pile size (more cards = more visible stacking)
    final stackOffset = (pile.length - 1).clamp(0, 3) * 5.0;
    
    return SizedBox(
      width: GameTheme.cardWidth,
      height: GameTheme.cardHeight + stackOffset + 15,
      child: Stack(
        children: [
          // Starting card (first card) - shows at top, peeking
          if (pile.length > 1)
            Positioned(
              top: 0,
              left: 0,
              child: Draggable<PlayingCard>(
                data: pile.cards.first,
                feedback: Material(
                  color: Colors.transparent,
                  child: Transform.scale(
                    scale: 1.1,
                    child: GlassCard(card: pile.cards.first),
                  ),
                ),
                childWhenDragging: Opacity(
                  opacity: 0.3,
                  child: Container(
                    width: GameTheme.cardWidth,
                    height: 25,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(GameTheme.cardRadius),
                        topRight: Radius.circular(GameTheme.cardRadius),
                      ),
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${pile.cards.first.rank.symbol}${pile.cards.first.suit.symbol}',
                        style: TextStyle(
                          color: pile.cards.first.color == CardColor.red 
                            ? GameTheme.cardRed 
                            : GameTheme.cardBlack,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                child: Container(
                  width: GameTheme.cardWidth,
                  height: 25,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(GameTheme.cardRadius),
                      topRight: Radius.circular(GameTheme.cardRadius),
                    ),
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${pile.cards.first.rank.symbol}${pile.cards.first.suit.symbol}',
                      style: TextStyle(
                        color: pile.cards.first.color == CardColor.red 
                          ? GameTheme.cardRed 
                          : GameTheme.cardBlack,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // Stack indicator (shows more cards between first and top)
          if (pile.length > 2)
            for (int i = 0; i < (pile.length - 2).clamp(0, 2); i++)
              Positioned(
                top: 20 + (i * 5.0),
                left: 0,
                child: Container(
                  width: GameTheme.cardWidth,
                  height: GameTheme.cardHeight,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7 - (i * 0.2)),
                    borderRadius: BorderRadius.circular(GameTheme.cardRadius),
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                ),
              ),
          // Top card - fully visible and draggable
          Positioned(
            top: pile.length > 1 ? 20.0 + stackOffset - 5 : 0.0,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Draggable<PlayingCard>(
                  data: pile.cards.last,
                  feedback: Material(
                    color: Colors.transparent,
                    child: Transform.scale(
                      scale: 1.1,
                      child: GlassCard(card: pile.cards.last),
                    ),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.3,
                    child: GlassCard(card: pile.cards.last),
                  ),
                  child: GlassCard(card: pile.cards.last),
                ),
                // Card count badge if more than 1 card
                if (pile.length > 1)
                  Positioned(
                    bottom: -6,
                    right: -6,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: GameTheme.secondary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          '${pile.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleDrawThree() {
    print("Handling Draw Three Move");
    onMove?.call(Move(
      type: MoveType.drawThree,
      playerId: currentPlayerId,
    ));
  }
  
  /// Build animated waste pile showing up to 3 cards with staggered reveal
  Widget _buildAnimatedWastePile(PlayerState player) {
    if (player.wastePile.isEmpty) {
      return const GhostSlot();
    }
    
    // Get the last 3 cards (or fewer if not enough)
    final wasteCards = player.wastePile.cards;
    final cardsToShow = wasteCards.length > 3 
        ? wasteCards.sublist(wasteCards.length - 3) 
        : wasteCards.toList();
    
    // Calculate how many cards are "new" (from the current draw)
    final newCardsCount = wasteCards.length - _previousWasteCount;
    final animatingCount = newCardsCount.clamp(0, 3);
    
    // Determine which cards to show based on animation state
    int cardsVisible;
    if (animatingCount > 0 && _visibleWasteCards < animatingCount) {
      // Still animating - show old cards plus newly revealed cards
      final oldCardsToShow = (cardsToShow.length - animatingCount).clamp(0, cardsToShow.length);
      cardsVisible = oldCardsToShow + _visibleWasteCards;
    } else {
      // Not animating or animation complete - show all available
      cardsVisible = cardsToShow.length;
    }
    
    // Clamp to available cards
    cardsVisible = cardsVisible.clamp(0, cardsToShow.length);
    
    if (cardsVisible == 0) {
      return const GhostSlot();
    }
    
    final visibleCards = cardsToShow.sublist(cardsToShow.length - cardsVisible);
    
    return SizedBox(
      width: GameTheme.cardWidth + (visibleCards.length - 1) * 15,
      height: GameTheme.cardHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int i = 0; i < visibleCards.length; i++)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              left: i * 15.0,
              child: i == visibleCards.length - 1
                  // Top card is draggable
                  ? Draggable<PlayingCard>(
                      data: visibleCards[i],
                      feedback: Material(
                        color: Colors.transparent,
                        child: Transform.scale(
                          scale: 1.1,
                          child: GlassCard(card: visibleCards[i]),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.3,
                        child: GlassCard(card: visibleCards[i]),
                      ),
                      child: GlassCard(card: visibleCards[i]),
                    )
                  // Other cards are just visible
                  : GlassCard(card: visibleCards[i]),
            ),
        ],
      ),
    );
  }
}
