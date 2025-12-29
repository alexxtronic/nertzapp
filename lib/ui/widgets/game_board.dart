/// Game board widget for Nertz Royale

library;

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/card.dart';
import '../../models/game_state.dart';
import '../../models/player_state.dart';
import '../../models/pile.dart';
import '../../engine/move_validator.dart';
import '../theme/game_theme.dart';
import 'package:confetti/confetti.dart';
import '../../services/audio_service.dart';
import '../../utils/player_colors.dart';
import 'settings_dialog.dart';
import 'package:nertz_royale/ui/widgets/opponent_board.dart';

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
    this.isCenterPile = false,
  });

  final bool isCenterPile;

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
    
    if (isCenterPile) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              card.rank.symbol,
              style: TextStyle(
                color: color,
                fontSize: 28, // Much larger for visibility
                fontWeight: FontWeight.bold,
                fontFamily: 'SF Pro Rounded',
                height: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              card.suit.symbol,
              style: TextStyle(
                color: color,
                fontSize: 24, // Larger suit
                height: 1.0,
              ),
            ),
          ],
        ),
      );
    }

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
  final String selectedCardBack; // Card back asset path
  final Function(Move)? onMove;
  final Function(PlayingCard)? onCardDoubleTap;
  final VoidCallback? onCenterPilePlaced;
  final VoidCallback? onLeaveMatch;
  final VoidCallback? onVoteReset;
  
  const GameBoard({
    super.key,
    required this.gameState,
    required this.currentPlayerId,
    this.style = CardStyle.normal,
    this.selectedCardBack = 'assets/card_back.png',
    this.onMove,
    this.onCardDoubleTap,
    this.onCenterPilePlaced,
    this.onLeaveMatch,
    this.onVoteReset,
  });

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> with TickerProviderStateMixin {
  bool _isDrawing = false;
  
  // Animation state for waste pile - track revealed card IDs
  Set<String> _revealedCardIds = {};
  List<Timer> _cardRevealTimers = [];
  // Track the number of cards to animate (set before draw, used during animation)
  int _cardsToAnimate = 0;
  
  // Countdown State
  int _countdownValue = 0;
  bool _showCountdown = false;
  Timer? _countdownTimer;
  
  // Card dealing animation during countdown
  double _dealProgress = 0.0; // 0 to 1 representing cards dealt
  List<double> _cardAnimations = []; // Animation progress for each dealt card
  
  // Confetti
  late ConfettiController _confettiController;

  GameState get gameState => widget.gameState;
  String get currentPlayerId => widget.currentPlayerId;
  Function(Move)? get onMove => widget.onMove;
  VoidCallback? get onCenterPilePlaced => widget.onCenterPilePlaced;

  PlayerState? get currentPlayer => gameState.getPlayer(currentPlayerId);
  
  List<PlayerState> get opponents => gameState.players.values
      .where((p) => p.id != currentPlayerId)
      .where((p) => p.id != currentPlayerId)
      .where((p) => p.id != currentPlayerId)
      .toList();
      
  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    
    // If we mount the widget while already playing, start the countdown
    if (widget.gameState.phase == GamePhase.playing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startCountdown();
      });
    }
  }

  @override
  void didUpdateWidget(GameBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Detect transition to Playing phase to start countdown
    if (oldWidget.gameState.phase != GamePhase.playing && 
        widget.gameState.phase == GamePhase.playing) {
      _startCountdown();
    }
    
    // Play applause on match win
    if (oldWidget.gameState.phase != GamePhase.matchEnd && 
        widget.gameState.phase == GamePhase.matchEnd) {
      // Check if we won? Or just play applause generally? 
      // User said "applause at the end of the game for the winner".
      // Assuming generic applause for everyone for now, or check winner?
      // "the person who hits 100 points first".
      // Let's just play it.
      AudioService().playApplause();
    }
  }
  
  void _startCountdown() {
    setState(() {
      _showCountdown = true;
      _countdownValue = 3;
      _dealProgress = 0.0;
      _cardAnimations = List.filled(13, 0.0); // 13 cards for nertz pile
    });
    
    // Play shuffle sound at start of dealing
    AudioService().playShuffle();
    
    _countdownTimer?.cancel();
    
    // Animate card dealing over 3 seconds (during countdown)
    // Deal cards progressively
    int cardIndex = 0;
    Timer.periodic(const Duration(milliseconds: 200), (dealTimer) {
      if (!mounted || cardIndex >= 13) {
        dealTimer.cancel();
        return;
      }
      setState(() {
        _cardAnimations[cardIndex] = 1.0;
        cardIndex++;
        _dealProgress = cardIndex / 13;
      });
    });
    
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        if (_countdownValue > 1) {
          _countdownValue--;
        } else if (_countdownValue == 1) {
           _countdownValue = 0; // Show "NERTZ!" or "GO!"
           AudioService().playGo(); // GO!
        } else {
           // Done
           _showCountdown = false;
           timer.cancel();
        }
      });
    });
  }
  
  @override
  void dispose() {
    for (final timer in _cardRevealTimers) {
      timer.cancel();
    }
    _countdownTimer?.cancel();
    _confettiController.dispose();
    super.dispose();
  }
  
  /// Draw up to 3 cards from stock to waste with staggered animation
  void _drawFromStock() {
    debugPrint('🎴 _drawFromStock called. _isDrawing=$_isDrawing');
    if (_isDrawing) {
      debugPrint('🎴 Ignoring - already drawing');
      return;
    }
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
    _cardsToAnimate = cardsToDraw;
    
    debugPrint('🎴 Stock has ${player.stockPile.length} cards, drawing $cardsToDraw');
    
    // Capture the IDs of cards that will be drawn (they're at the top of the stock pile)
    // Stock pile is LIFO, so the last N cards will be drawn
    final stockCards = player.stockPile.cards;
    final cardsBeingDrawn = stockCards.sublist(stockCards.length - cardsToDraw).reversed.toList();
    final cardIdsBeingDrawn = cardsBeingDrawn.map((c) => c.id).toList();
    
    debugPrint('🎴 Cards being drawn: $cardIdsBeingDrawn');
    
    // Clear the revealed cards set - none are visible initially
    _revealedCardIds = {};
    
    // Execute the draw move
    onMove?.call(Move(
      type: MoveType.drawThree,
      playerId: currentPlayerId,
    ));
    
    debugPrint('🎴 Move executed. Starting animation timers...');
    
    // Animate cards appearing one at a time at 0.15s intervals
    for (int i = 0; i < cardIdsBeingDrawn.length; i++) {
      final cardId = cardIdsBeingDrawn[i];
      final timer = Timer(Duration(milliseconds: 150 * (i + 1)), () {
        if (mounted) {
          debugPrint('🎴 Revealing card ${i + 1}/$cardsToDraw: $cardId');
          setState(() {
            _revealedCardIds.add(cardId);
          });
          
          // Haptic feedback
          if (i == cardIdsBeingDrawn.length - 1) {
             HapticFeedback.mediumImpact(); // Heavier for final card
          } else {
             HapticFeedback.lightImpact(); // Light for others
          }
        }
      });
      _cardRevealTimers.add(timer);
    }
    
    // Allow next draw after animation completes
    Timer(Duration(milliseconds: 150 * cardsToDraw + 100), () {
      debugPrint('🎴 Animation complete. Resetting _isDrawing');
      _isDrawing = false;
      // After animation completes, mark all cards as revealed
      if (mounted) {
        setState(() {
          _cardsToAnimate = 0;
        });
      }
    });
  }

  /// Reset the stock pile from waste
  void _resetStock() {
    final player = currentPlayer;
    if (player == null) return;
    if (!player.stockPile.isEmpty) return; // Only reset if empty
    if (player.wastePile.isEmpty) return;  // Nothing to reset

    // Play shuffle sound only when actually resetting
    AudioService().playShuffle();
    
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
        child: Stack( // Changed to Stack for overlay
          children: [
            LayoutBuilder(
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
                          _buildOpponentsRow(),
                          _buildCenterArea(),
                          const SizedBox(height: 12),
                          _buildWorkPiles(context, player),
                          const SizedBox(height: 16),
                          _buildPlayerHand(player),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            if (_showCountdown) _buildCountdownOverlay(),
            Align(
              alignment: Alignment.center,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [Colors.red, Colors.blue, Colors.green, Colors.yellow, Colors.purple],
                createParticlePath: drawStar, 
              ),
            ),
            _buildVoteBanner(),
          ],
        ),
      ),
    );
  }

  Widget _buildVoteBanner() {
    if (gameState.resetVotes.isEmpty) return const SizedBox.shrink();
    
    return Positioned(
      bottom: 100, // Just above the hand/button
      left: 20, // Aligned with the button
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: GameTheme.error.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: GameTheme.softShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'RESET?',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
            const SizedBox(width: 4),
            ...gameState.players.keys.map((pid) {
               final voted = gameState.resetVotes.contains(pid);
               return Padding(
                 padding: const EdgeInsets.symmetric(horizontal: 1),
                 child: Icon(
                   voted ? Icons.check_circle : Icons.radio_button_unchecked,
                   color: Colors.white,
                   size: 10,
                 ),
               );
             }),
          ],
        ),
      ),
    );
  }
  
  /// Helper to draw star confetti
  Path drawStar(Size size) {
    // Method to convert degree to radians
    double degToRad(double deg) => deg * (math.pi / 180.0);

    const numberOfPoints = 5;
    final halfWidth = size.width / 2;
    final externalRadius = halfWidth;
    final internalRadius = halfWidth / 2.5;
    final degreesPerStep = degToRad(360 / numberOfPoints);
    final halfDegreesPerStep = degreesPerStep / 2;
    final path = Path();
    final fullAngle = degToRad(360);
    path.moveTo(size.width, halfWidth);

    for (double step = 0; step < fullAngle; step += degreesPerStep) {
      path.lineTo(halfWidth + externalRadius * math.cos(step),
          halfWidth + externalRadius * math.sin(step));
      path.lineTo(halfWidth + internalRadius * math.cos(step + halfDegreesPerStep),
          halfWidth + internalRadius * math.sin(step + halfDegreesPerStep));
    }
    path.close();
    return path;
  }



  Widget _buildOpponentsRow() {
    final opponents = gameState.activeOpponents(currentPlayerId);
    if (opponents.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: opponents.map((player) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: OpponentBoard(player: player),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHeader(PlayerState player) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Left: Title
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
          ),
          
          // Center: Points Pill
            Align(
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: GameTheme.pillGradient,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: GameTheme.primary.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
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
                  const SizedBox(height: 4),
                  if (gameState.phase == GamePhase.playing && gameState.roundStartTime != null)
                    StreamBuilder(
                      stream: Stream.periodic(const Duration(seconds: 1)),
                      builder: (context, snapshot) {
                        final diff = DateTime.now().difference(gameState.roundStartTime!);
                        // Subtract 4 seconds for countdown
                        final playSeconds = (diff.inSeconds - 4).clamp(0, 3600);
                        final m = (playSeconds ~/ 60).toString().padLeft(2, '0');
                        final s = (playSeconds % 60).toString().padLeft(2, '0');
                        return Text(
                          "$m:$s",
                          style: TextStyle(
                            color: GameTheme.textPrimary.withValues(alpha: 0.5),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          
          // Right: Settings
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              decoration: BoxDecoration(
                color: GameTheme.background.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.settings, color: GameTheme.textSecondary, size: 24),
                onPressed: () {
                  showSettingsDialog(context, onLeaveMatch: widget.onLeaveMatch);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterArea() {
    // 5% larger than before (was 84%, now 89% of normal)
    // Restored scale (0.89) for center piles
    const double miniCardWidth = GameTheme.cardWidth * 0.89;
    const double miniCardHeight = GameTheme.cardHeight * 0.89;
    
    // Circular layout for 16 cards
    // Positions arranged in concentric arcs
    return Column(
      children: [
        // Shift down by card height
        // SizedBox(height: GameTheme.cardHeight * 0.3),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
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
                '${gameState.centerPiles.where((p) => !p.isEmpty).length}/18',
                style: TextStyle(
                  color: GameTheme.textSecondary.withValues(alpha: 0.6),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Simple 3x6 grid layout (3 rows of 6 cards)
        for (int row = 0; row < 3; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(), // Just to allow overflow if needed without error
              child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (col) {
                final index = row * 6 + col;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: _buildCenterPileSlot(index, miniCardWidth, miniCardHeight),
                );
              }),
            ),
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
                fontSize: 24, // Increased from 14
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              card.suit.symbol,
              style: TextStyle(
                color: color,
                fontSize: 20, // Increased from 12
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterPileSlot(int index, double width, double height) {
    final pile = gameState.centerPiles[index];
    
    // Check if this card was recently placed (within 2 seconds)
    bool showGlow = false;
    Color? glowColor;
    
    if (pile.lastPlacedTime != null && pile.lastPlayerId != null) {
      final elapsed = DateTime.now().difference(pile.lastPlacedTime!);
      if (elapsed.inSeconds < 2) {
        showGlow = true;
        // Find the player to get their color
        final player = gameState.getPlayer(pile.lastPlayerId!);
        if (player?.playerColor != null) {
          glowColor = PlayerColors.intToColor(player!.playerColor);
        }
      }
    }
    
    return DragTarget<PlayingCard>(
      onWillAcceptWithDetails: (details) {
        return pile.canAdd(details.data);
      },
      onAcceptWithDetails: (details) {
        HapticFeedback.lightImpact(); // Tactile feedback
        AudioService().playPing(); // Play ping sound
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
              color: Colors.black.withValues(alpha: 0.15),
              width: 1.5,
            ),
            // Add color glow if recently placed
            boxShadow: showGlow && glowColor != null ? [
              BoxShadow(
                color: glowColor.withValues(alpha: 0.8),
                blurRadius: 12,
                spreadRadius: 3,
              ),
              BoxShadow(
                color: glowColor.withValues(alpha: 0.4),
                blurRadius: 20,
                spreadRadius: 6,
              ),
            ] : null,
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
          // Nertz Pile + Stuck Button Group
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Nertz Pile (Far Left)
              Column(
            children: [
              player.nertzPile.isEmpty
                ? GestureDetector(
                    onTap: () {
                      HapticFeedback.heavyImpact(); // Strong haptics
                      AudioService().playExplosion();
                      AudioService().playApplause();
                      _confettiController.play();
                      
                      onMove?.call(Move(
                        type: MoveType.callNertz, 
                        playerId: currentPlayerId
                      ));
                    },
                    child: Container(
                      width: GameTheme.cardWidth,
                      height: GameTheme.cardHeight,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: GameTheme.primary.withValues(alpha: 0.5),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ]
                      ),
                      child: Image.asset('assets/nertz_button.png'),
                    ),
                  )
                : Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(GameTheme.cardRadius),
                          // Add player color glow
                          boxShadow: [
                            if (player.playerColor != null)
                              BoxShadow(
                                color: (PlayerColors.intToColor(player.playerColor) ?? Colors.grey).withValues(alpha: 0.5),
                                blurRadius: 16,
                                spreadRadius: 4,
                              ),
                            ...GameTheme.softShadow,
                          ],
                        ),
                        child: Draggable<PlayingCard>(
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
            
            // Stuck Button (Next to Nertz Pile)
            if (gameState.phase == GamePhase.playing)
              _buildStuckButton(),
              
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
                    // Tap handles both Drawing (if cards exist) and Resetting (if empty & can reset)
                    onTap: () {
                      if (!player.stockPile.isEmpty) {
                        _drawFromStock();
                      } else if (!player.wastePile.isEmpty) {
                        _resetStock();
                      }
                    },
                    behavior: HitTestBehavior.opaque,
                    child: player.stockPile.isEmpty
                      ? (player.wastePile.isEmpty 
                          // Completely Empty: Ghost Slot
                          ? const GhostSlot(label: "")
                          // Empty Stock but Waste has cards: RESET CARD
                          : Container(
                              width: GameTheme.cardWidth * 1.1,
                              height: GameTheme.cardHeight * 1.1,
                              decoration: BoxDecoration(
                                color: GameTheme.primary,
                                borderRadius: BorderRadius.circular(GameTheme.cardRadius),
                                boxShadow: [
                                  BoxShadow(
                                    color: GameTheme.primary.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                                border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
                              ),
                              child: const Center(
                                child: Text(
                                  "RESET",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                            ))
                      // Normal Stock Pile functionality
                      : Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: GameTheme.cardWidth * 1.25,
                              height: GameTheme.cardHeight * 1.25,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(GameTheme.cardRadius),
                                boxShadow: GameTheme.softShadow,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(GameTheme.cardRadius),
                                child: Image.asset(
                                  widget.selectedCardBack,
                                  width: GameTheme.cardWidth * 1.25,
                                  height: GameTheme.cardHeight * 1.25,
                                  fit: BoxFit.fill,
                                  errorBuilder: (context, error, stackTrace) {
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
              HapticFeedback.lightImpact(); // Tactile feedback
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
    
    // Condensed cascade view - Show every card directly with small offset
    const double cascadeOffset = 18.0;
    
    // Calculate total height to ensure SizedBox is large enough
    double totalHeight = GameTheme.cardHeight + ((pile.length - 1) * cascadeOffset);
    
    return SizedBox(
      width: GameTheme.cardWidth,
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: List.generate(pile.length, (index) {
          final card = pile.cards[index];
          final isTopCard = index == pile.length - 1;
          
          return Positioned(
            top: index * cascadeOffset,
            left: 0,
            child: isTopCard
              ? Draggable<PlayingCard>(
                  data: card,
                  feedback: Material(
                    color: Colors.transparent,
                    child: Transform.scale(
                      scale: 1.1,
                      child: GlassCard(card: card),
                    ),
                  ),
                  childWhenDragging: Opacity(opacity: 0.3, child: GlassCard(card: card)),
                  child: GlassCard(card: card),
                )
              : GlassCard(card: card), 
          );
        }),
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
    
    // Determine which cards to display:
    // If we're in animation mode (_cardsToAnimate > 0), only show cards that are:
    // 1. Already revealed (in _revealedCardIds), OR
    // 2. Not part of this draw (they were already in the waste pile before)
    List<PlayingCard> visibleCards;
    
    if (_cardsToAnimate > 0) {
      // Get the newly drawn cards (last N cards where N = _cardsToAnimate)
      final newlyDrawnStart = wasteCards.length - _cardsToAnimate;
      visibleCards = [];
      
      for (int i = 0; i < cardsToShow.length; i++) {
        final card = cardsToShow[i];
        final cardIndexInWaste = wasteCards.indexOf(card);
        
        // Show the card if:
        // 1. It was already in waste before draw (not a new card), OR
        // 2. It's a new card that has been revealed
        if (cardIndexInWaste < newlyDrawnStart || _revealedCardIds.contains(card.id)) {
          visibleCards.add(card);
        }
      }
    } else {
      // Not animating - show all cards
      visibleCards = cardsToShow;
    }
    
    if (visibleCards.isEmpty) {
      return const GhostSlot();
    }
    
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

  Widget _buildCountdownOverlay() {
    String text;
    if (_countdownValue > 0) {
      text = _countdownValue.toString();
    } else {
      text = "NERTZ!";
    }
    
    // Simplified overlay: Just the text, centered, with no background
    return Center(
      child: TweenAnimationBuilder<double>(
        key: ValueKey(_countdownValue),
        tween: Tween(begin: 0.5, end: 1.0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.elasticOut,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 100,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(color: Colors.black, blurRadius: 15, offset: Offset(4, 4)),
                  Shadow(color: GameTheme.primary, blurRadius: 30),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildAnimatedDeck() {
    // Show remaining cards in deck
    final cardsRemaining = 13 - (_dealProgress * 13).floor();
    return Stack(
      children: [
        for (int i = 0; i < cardsRemaining; i++)
          Positioned(
            top: -i * 0.5,
            left: i * 0.3,
            child: Container(
              width: 50,
              height: 70,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [GameTheme.primary, GameTheme.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 2,
                    offset: const Offset(1, 1),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
  Widget _buildStuckButton() {
     final hasVoted = gameState.resetVotes.contains(currentPlayerId);
     return GestureDetector(
       onTap: widget.onVoteReset, // Always allow tap to toggle
       child: Container(
         width: 48,
         height: 48,
         margin: const EdgeInsets.only(left: 12, bottom: 20),
         decoration: BoxDecoration(
           color: hasVoted ? Colors.grey : const Color(0xFFFF4444),
           shape: BoxShape.circle,
           boxShadow: [
             BoxShadow(
               color: (hasVoted ? Colors.grey : const Color(0xFFFF4444)).withValues(alpha: 0.4),
               blurRadius: 8,
               offset: const Offset(0, 2),
             ),
           ],
           border: Border.all(
             color: Colors.white.withValues(alpha: 0.3),
             width: 2,
           ),
         ),
         child: Center(
           child: hasVoted 
             ? const Icon(Icons.close, color: Colors.white, size: 24) // X to cancel
             : const Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   Text(
                     'Stuck',
                     style: TextStyle(
                       color: Colors.white,
                       fontSize: 10,
                       fontWeight: FontWeight.w900,
                       letterSpacing: 0.5,
                     ),
                   ),
                   Icon(Icons.refresh, color: Colors.white, size: 14),
                 ],
               ),
         ),
       ),
     );
  }
}
