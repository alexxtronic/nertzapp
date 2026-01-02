/// Game board widget for Nertz Royale

library;

import 'dart:async';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/card.dart';
import '../../models/game_state.dart';
import '../../models/player_state.dart';
import '../../models/pile.dart';
import '../../engine/move_validator.dart';
import '../theme/game_theme.dart';
import 'reset_vote_dialog.dart';
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
    this.compact = false,
  });

  final bool isCenterPile;
  final bool compact;

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

    if (compact) {
      // Super compact mode for stacked work piles
      // "shrink and move far to the top"
      return Stack(
        children: [
          Positioned(
            top: 1, // "far to the top"
            left: 2,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  card.rank.symbol,
                  style: TextStyle(
                    color: color,
                    fontSize: 13, // Slightly smaller to ensure fit
                    fontWeight: FontWeight.bold,
                    fontFamily: 'SF Pro Rounded',
                    height: 1.0,
                  ),
                ),
                const SizedBox(width: 2), // Slightly more separation
                Text(
                  card.suit.symbol,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
          // Clean look - no bottom stats in compact mode to reduce noise
        ],
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
  final Function(PlayingCard)? onCenterPilePlaced;
  final VoidCallback? onLeaveMatch;
  final VoidCallback? onVoteReset;
  final VoidCallback? onShuffleDeck;
  
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
    this.onShuffleDeck,
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
  
  // Track if vote dialog is showing (to prevent duplicates)
  bool _isVoteDialogShowing = false;
  
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
  Function(PlayingCard)? get onCenterPilePlaced => widget.onCenterPilePlaced;

  PlayerState? get currentPlayer => gameState.getPlayer(currentPlayerId);
  
  List<PlayerState> get opponents => gameState.activeOpponents(currentPlayerId);
      
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
    
    // Detect Reset (Vote Passed)
    final oldReset = oldWidget.gameState.lastResetTime;
    final newReset = widget.gameState.lastResetTime;
    if (oldReset != newReset && newReset != null) {
      // Check for recent reset (within 5 seconds)
      if (DateTime.now().difference(newReset).inSeconds < 5) {
        AudioService().playShuffle();
        // Force rebuild to show 'Vote Passed!' banner
        setState(() {}); 
        // Hide it after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
           if (mounted) setState(() {});
        });
        
        // Dismiss vote dialog if showing
        if (_isVoteDialogShowing && mounted) {
          Navigator.of(context).pop();
          _isVoteDialogShowing = false;
        }
      }
    }
    
    // Detect remote vote initiation and show dialog
    final newInitiator = widget.gameState.resetVoteInitiatorId;
    final wasEmpty = oldWidget.gameState.resetVotes.isEmpty;
    final isNotEmpty = widget.gameState.resetVotes.isNotEmpty;
    
    // Show dialog if:
    // 1. Vote just started (votes was empty, now not empty)
    // 2. Initiator is NOT current player (remote vote)
    // 3. Dialog not already showing
    // 4. Current player hasn't voted yet
    if (wasEmpty && isNotEmpty && 
        newInitiator != null && 
        newInitiator != currentPlayerId &&
        !_isVoteDialogShowing &&
        !widget.gameState.resetVotes.contains(currentPlayerId)) {
      
      // Show the vote dialog
      _showVoteDialog(newInitiator);
    }
    
    // Dismiss dialog if votes were cleared
    if (!wasEmpty && widget.gameState.resetVotes.isEmpty && _isVoteDialogShowing) {
      if (mounted) {
        Navigator.of(context).pop();
        _isVoteDialogShowing = false;
      }
    }
    
    // Play ding sound when Nertz pile becomes empty
    final oldNertzEmpty = oldWidget.gameState.getPlayer(currentPlayerId)?.nertzPile.isEmpty ?? false;
    final newNertzEmpty = widget.gameState.getPlayer(currentPlayerId)?.nertzPile.isEmpty ?? false;
    
    if (!oldNertzEmpty && newNertzEmpty) {
      AudioService().playDing();
    }
  }
  
  void _showVoteDialog(String initiatorId) {
    final initiator = gameState.players[initiatorId];
    if (initiator == null) return;
    
    _isVoteDialogShowing = true;
    
    showResetVoteDialog(
      context,
      initiatorName: initiator.displayName,
      hasVoted: gameState.resetVotes.contains(currentPlayerId),
      onAgree: () {
        _isVoteDialogShowing = false;
        widget.onVoteReset?.call();
      },
      onDecline: () {
        _isVoteDialogShowing = false;
        // Decline just closes dialog - user chooses not to vote
        // They can vote later via the Stuck button if they change their mind
      },
    );
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

    // Container removed as background is now handled by GameScreen
    return SafeArea(
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
                      mainAxisAlignment: MainAxisAlignment.center, // Center vertical content
                      children: [
                        _buildHeader(player),
                        const Spacer(flex: 3), // TOP SPACE (tighter)
                        _buildOpponentsRow(),
                        const SizedBox(height: 8), // Spacing after bots (moved down)
                        _buildCenterArea(),
                        const SizedBox(height: 4), // Tighter gap to work piles (moved up)
                        _buildWorkPiles(context, player),
                        const Spacer(flex: 14), // Push player hand down more
                        _buildPlayerHand(player),
                        const SizedBox(height: 64), 
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
        ],
      ),
    );
  }

  /// Build persistent reset status widget (embedded in layout)
  Widget _buildResetStatus() {
    final lastReset = gameState.lastResetTime;
    final isRecentReset = lastReset != null && 
        DateTime.now().difference(lastReset).inSeconds < 2;

    if (!isRecentReset && gameState.resetVotes.isEmpty) return const SizedBox.shrink();
    
    return Container(
      // Margin removed to facilitate absolute positioning below nertz pile without shifting layout
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isRecentReset 
            ? Colors.green.withValues(alpha: 0.9)
            : GameTheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        border: isRecentReset ? null : Border.all(color: GameTheme.error, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isRecentReset ? 'Vote Passed!' : 'Reset vote initiated',
            style: TextStyle(
              color: isRecentReset ? Colors.white : GameTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
          if (!isRecentReset) ...[
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: gameState.players.keys.map((pid) {
                 final voted = gameState.resetVotes.contains(pid);
                 return Padding(
                   padding: const EdgeInsets.only(right: 2),
                   child: Icon(
                     voted ? Icons.check_circle : Icons.radio_button_unchecked,
                     color: voted ? GameTheme.error : GameTheme.textSecondary,
                     size: 10,
                   ),
                 );
               }).toList(),
            ),
          ],
        ],
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
          // Left: Shuffle Deck Button (replaces NERTZ ROYALE text)
          Align(
            alignment: Alignment.centerLeft,
            child: gameState.phase == GamePhase.playing
              ? Padding(
                  padding: const EdgeInsets.only(left: 40), // Move closer to center
                  child: _buildShuffleDeckButton(player),
                )
              : const SizedBox.shrink(),
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
                        const Icon(Icons.add, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        // Round Points
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${gameState.getPlayer(currentPlayerId)?.calculateRoundScore(gameState.countScorableCenterCards(currentPlayerId)) ?? 0} pts',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        // Separator
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Container(
                            width: 1.5,
                            height: 14,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        // Overall Points with Trophy
                        const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${player.scoreTotal}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
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
          
          // Right: Controls
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Stuck Button
                if (gameState.phase == GamePhase.playing)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildStuckButton(),
                  ),
                
                // Settings
                Container(
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterArea() {
    // 5% larger than before (was 84%, now 89% of normal)
    // Scaled for 6 columns (0.75 to save space)
    const double miniCardWidth = GameTheme.cardWidth * 0.75;
    const double miniCardHeight = GameTheme.cardHeight * 0.75;
    
    return Column(
      children: [
        // Simple 3x6 grid layout (3 rows of 6 cards)
        for (int row = 0; row < 3; row++)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (col) {
              final index = row * 6 + col;
              return _buildCenterPileSlot(index, miniCardWidth, miniCardHeight);
            }),
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
      hitTestBehavior: HitTestBehavior.opaque,
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
        onCenterPilePlaced?.call(details.data); // Trigger +1 animation
      },
      builder: (context, candidateData, rejectedData) {
        final isHighlighted = candidateData.isNotEmpty;
        // Use SizedBox for invisible hit zone expansion (doesn't affect visual layout)
        return SizedBox(
          width: width + 10, // Compact hit area padding
          height: height + 10,
          child: Center(
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: isHighlighted 
                  ? GameTheme.success.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isHighlighted ? GameTheme.success : Colors.black.withValues(alpha: 0.15),
                  width: 1.5,
                ),
                boxShadow: showGlow && glowColor != null ? [
                  BoxShadow(
                    color: glowColor.withValues(alpha: 0.8),
                    blurRadius: 12,
                    spreadRadius: 3,
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlayerHand(PlayerState player) {
    return Padding(
      padding: const EdgeInsets.only(left: 60, right: 16), // 60px left padding for Nertz pile alignment (moved right)
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end, // Align bottoms (Nertz aligns with Stock)
        children: [
          // Nertz Pile + Stuck Button Group
          // Wrap in Stack with Overflow.visible so reset status doesn't push layout up
          Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                   Column(
                     children: [
                         player.nertzPile.isEmpty
                           ? Column(
                               mainAxisSize: MainAxisSize.min,
                               children: [
                                 // Prompt above button (Text + Arrow Down)
                                 Container(
                                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                   decoration: BoxDecoration(
                                     color: Colors.white,
                                     borderRadius: BorderRadius.circular(16),
                                     boxShadow: GameTheme.softShadow,
                                     border: Border.all(color: GameTheme.error, width: 2),
                                   ),
                                   child: const Text(
                                     "Press Nertz!",
                                     style: TextStyle(
                                       color: GameTheme.error,
                                       fontWeight: FontWeight.bold,
                                       fontSize: 12,
                                     ),
                                   ),
                                 ),
                                 const SizedBox(height: 4),
                                 const Icon(Icons.arrow_downward, color: GameTheme.error, size: 24),
                                 const SizedBox(height: 4),
                                 
                                 GestureDetector(
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
                                 ),
                               ],
                             )
                          : Transform.translate(
                              offset: const Offset(0, -15), // Move up to align with discard pile bottom
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(GameTheme.cardRadius),
                                      // Add player color glow - increased for larger card
                                      boxShadow: [
                                        if (player.playerColor != null)
                                          BoxShadow(
                                            color: (PlayerColors.intToColor(player.playerColor) ?? Colors.grey).withValues(alpha: 0.6),
                                            blurRadius: 36, // Significantly larger glow
                                            spreadRadius: 12,
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
                                        child: GlassCard(card: player.nertzPile.cards.last), // Normal size when dragging
                                      ),
                                      child: Transform.scale(
                                        scale: 1.25, // 25% larger Nertz pile
                                        child: GlassCard(card: player.nertzPile.cards.last),
                                      ),
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
                            ),
                            const SizedBox(height: 8),
                            const Text("NERTZ", style: TextStyle(
                              color: GameTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold
                            )), 
                     ],
                   ),
                   
                   // Stuck Button moved to header
                ],
              ),
              
              // Absolute positioned reset status (does not push columns up)
              Positioned(
                top: GameTheme.cardHeight + 25, // Placed below the NERTZ label
                left: 0,
                child: _buildResetStatus(),
              ),
            ],
          ),
          
          // Waste + Stock (Right side: Waste left of Stock)
          Transform.translate(
            offset: const Offset(30, -8), // Move right another 25px (was 5, now 30)
            child: Row(
              children: [
                // Waste (left of Stock) - shows up to 3 cards fanned with animation
                Padding(
                  padding: const EdgeInsets.only(bottom: 25), // Push waste pile up ~20%
                  child: Transform.scale(
                    scale: 1.10, // 10% larger (reduced from 25%)
                    child: _buildAnimatedWastePile(player),
                  ),
                ),
                const SizedBox(width: 12),
                // Stock (Far Right) with extended hitbox
                GestureDetector(
                  // Tap anywhere in the stock area activates it
                  onTap: () {
                    if (!player.stockPile.isEmpty) {
                      _drawFromStock();
                    } else if (!player.wastePile.isEmpty) {
                      _resetStock();
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    // Add 50px padding to the right for extended hitbox
                    padding: const EdgeInsets.only(right: 50),
                    child: Column(
                      children: [
                        // Stabilize height to 1.30 scale
                        SizedBox(
                          width: GameTheme.cardWidth * 1.30,
                          height: GameTheme.cardHeight * 1.30,
                          child: Center(
                            child: player.stockPile.isEmpty
                              ? (player.wastePile.isEmpty 
                                  // Completely Empty: Ghost Slot
                                  ? const GhostSlot(label: "")
                                  // Empty Stock but Waste has cards: RESET CARD
                                  : Container(
                                      width: GameTheme.cardWidth * 1.30,
                                      height: GameTheme.cardHeight * 1.30,
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
                                            fontSize: 14,
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
                                      width: GameTheme.cardWidth * 1.30,
                                      height: GameTheme.cardHeight * 1.30,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(GameTheme.cardRadius),
                                        boxShadow: GameTheme.softShadow,
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(GameTheme.cardRadius),
                                        child: _buildCardBackImage(
                                          widget.selectedCardBack,
                                          GameTheme.cardWidth * 1.30,
                                          GameTheme.cardHeight * 1.30,
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
                        ),
                        
                        const SizedBox(height: 8),
                        const Text("STOCK", style: TextStyle(
                          color: GameTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold
                        )),
                      ],
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


  Widget _buildWorkPiles(BuildContext context, PlayerState player) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.start, // Align to top to prevent empty slots from drifting
        children: List.generate(4, (pileIndex) {
          final pile = player.workPiles[pileIndex];
          return DragTarget<PlayingCard>(
            hitTestBehavior: HitTestBehavior.opaque,
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
                // FORGIVING SNAP: Padding for larger hit zone around top card
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                color: Colors.transparent,
                child: Container(
                  width: GameTheme.cardWidth,
                  // Ensure the DragTarget is at least cardHeight + some room
                  constraints: const BoxConstraints(minHeight: GameTheme.cardHeight),
                  decoration: BoxDecoration(
                    color: isHighlighted 
                        ? GameTheme.success.withValues(alpha: 0.2) 
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(GameTheme.cardRadius),
                    border: isHighlighted 
                        ? Border.all(color: GameTheme.success, width: 2) 
                        : null,
                  ),
                  child: _buildWorkPileItem(pile, pileIndex),
                ),
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
    
    // FIXED LAYOUT: Height is constant regardless of pile size.
    final int count = pile.length;
    // User requested "shrink when there are more than 2 cards"
    final bool isLarge = count > 2; 
    
    // FIXED height
    const double maxPileHeight = GameTheme.cardHeight * 1.4;
    
    // Standard peek for the rest of the stack (don't push them down)
    const double standardPeek = 15.0; 
    
    // Calculate offset for remaining cards
    double baseOffset;
    if (count <= 1) {
      baseOffset = 20.0;
    } else if (count == 2) {
      baseOffset = standardPeek; 
    } else {
      final remainingHeight = maxPileHeight - GameTheme.cardHeight - standardPeek;
      baseOffset = (remainingHeight / (count - 2)).clamp(5.0, 25.0);
    }
    
    return SizedBox(
      width: GameTheme.cardWidth,
      height: maxPileHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: List.generate(count, (index) {
          final card = pile.cards[index];
          
          bool isDraggable = true;
          for (int i = index; i < count - 1; i++) {
             final current = pile.cards[i];
             final next = pile.cards[i + 1];
             if (!next.canPlaceOnWorkPile(current)) {
                 isDraggable = false;
                 break;
             }
          }
          
          // Compact Logic Refined:
          // "starting card also does the shrunk suit rank"
          // Only the LATEST card (Playable) remains Normal.
          // All underlying cards (First + Middle) are Compact.
          bool isCompact = false;
          if (isLarge) {
             // Index count-1 is Latest (Playable) - Normal
             // All others (0 to count-2) are Compact
             if (index < count - 1) {
               isCompact = true;
             }
          }
          
          final childWidget = GlassCard(
            card: card, 
            compact: isCompact, 
          );

          // POKE UP LOGIC:
          // Base card (Index 0) shifts up slightly to reveal its compact header.
          double topPos;
          if (index == 0) {
            // User request: "move the starting card down a tiny bit more" (was -6.0)
            topPos = isLarge ? -3.0 : 0.0;
          } else {
            topPos = standardPeek + (index - 1) * baseOffset;
          }

          return Positioned(
            top: topPos,
            left: 0,
            child: isDraggable
              ? Draggable<PlayingCard>(
                  data: card,
                  feedback: Material(
                    color: Colors.transparent,
                    child: SizedBox(
                      width: GameTheme.cardWidth,
                      height: GameTheme.cardHeight + ((count - index - 1) * baseOffset),
                      child: Stack(
                         clipBehavior: Clip.none,
                         children: List.generate(count - index, (subIndex) {
                             final subCard = pile.cards[index + subIndex];
                             final double subTop = subIndex * baseOffset;
                             return Positioned(
                               top: subTop,
                               child: GlassCard(card: subCard, compact: isLarge),
                             );
                         }),
                      ),
                    ),
                  ),
                  childWhenDragging: Opacity(
                     opacity: 0.3, 
                     child: childWidget,
                  ),
                  child: childWidget,
                )
              : childWidget, 
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

  Widget _buildShuffleDeckButton(PlayerState player) {
    // Calculate time since last playable action
    final lastAction = player.lastPlayableActionTime;
    final now = DateTime.now();
    // If no action yet (game just started), elapsed is 0 - button starts disabled
    final elapsed = lastAction != null ? now.difference(lastAction).inSeconds : 0;
    final progress = (elapsed / 45.0).clamp(0.0, 1.0); // 0.0 to 1.0 over 45 seconds
    final isAvailable = lastAction != null && elapsed >= 45;
    
    // Check if there are cards to shuffle
    final hasCards = !player.stockPile.isEmpty || !player.wastePile.isEmpty;
    
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, _) {
        // Recalculate on each tick
        final lastActionTime = player.lastPlayableActionTime;
        final currentTime = DateTime.now();
        // If no action yet, elapsed is 0 - button stays disabled until first action
        final elapsedNow = lastActionTime != null ? currentTime.difference(lastActionTime).inSeconds : 0;
        final progressNow = (elapsedNow / 45.0).clamp(0.0, 1.0);
        final available = lastActionTime != null && elapsedNow >= 45 && hasCards;
        
        return GestureDetector(
          onTap: available ? widget.onShuffleDeck : null,
          child: Container(
            width: 40,
            height: 40,
            child: Stack(
              children: [
                // Background circle with pie-chart progress
                CustomPaint(
                  size: const Size(40, 40),
                  painter: _PieChartPainter(
                    progress: progressNow,
                    backgroundColor: Colors.grey.shade300,
                    progressColor: available ? const Color(0xFFFF4444) : Colors.grey.shade500,
                  ),
                ),
                // Inner content
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: available ? const Color(0xFFFF4444) : Colors.grey.shade400,
                    shape: BoxShape.circle,
                    boxShadow: available ? [
                      BoxShadow(
                        color: const Color(0xFFFF4444).withValues(alpha: 0.5),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ] : null,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Shuffle',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 6,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                        ),
                        Icon(
                          Icons.shuffle,
                          color: Colors.white,
                          size: 12,
                        ),
                      ],
                    ),
                  ),
                ),
                // Pie-chart overlay showing progress (ring around edge)
                if (!available)
                  CustomPaint(
                    size: const Size(40, 40),
                    painter: _PieProgressRingPainter(
                      progress: progressNow,
                      ringColor: Colors.grey.shade600,
                      backgroundColor: Colors.transparent,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildStuckButton() {
     final hasVoted = gameState.resetVotes.contains(currentPlayerId);
     // Orange color for stuck button (to distinguish from red shuffle button)
     const stuckColor = Color(0xFFFF9800); // Orange
     return GestureDetector(
       onTap: widget.onVoteReset, // Always allow tap to toggle
       child: Container(
         width: 40,
         height: 40,
         decoration: BoxDecoration(
           color: hasVoted ? Colors.grey : stuckColor,
           shape: BoxShape.circle,
           boxShadow: [
             BoxShadow(
               color: (hasVoted ? Colors.grey : stuckColor).withValues(alpha: 0.4),
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
             ? const Icon(Icons.close, color: Colors.white, size: 20) // X to cancel
             : const Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   Text(
                     'Stuck',
                     style: TextStyle(
                       color: Colors.white,
                       fontSize: 8,
                       fontWeight: FontWeight.w900,
                       letterSpacing: 0.5,
                     ),
                   ),
                   Icon(Icons.check, color: Colors.white, size: 14),
                 ],
               ),
         ),
       ),
     );
  }
  
  /// Builds a card back image that handles both cloud URLs and local assets
  Widget _buildCardBackImage(String path, double width, double height) {
    // If it's a URL (from Supabase Storage), use CachedNetworkImage
    if (path.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: path,
        width: width,
        height: height,
        fit: BoxFit.fill,
        placeholder: (context, url) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: GameTheme.primaryGradient,
            borderRadius: BorderRadius.circular(GameTheme.cardRadius),
          ),
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          width: width,
          height: height,
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
        ),
      );
    }
    
    // Otherwise, load from local assets
    return Image.asset(
      path,
      width: width,
      height: height,
      fit: BoxFit.fill,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: width,
          height: height,
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
    );
  }
}

/// Custom painter for pie-chart style progress indicator
class _PieChartPainter extends CustomPainter {
  final double progress;
  final Color backgroundColor;
  final Color progressColor;

  _PieChartPainter({
    required this.progress,
    required this.backgroundColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    // Background circle
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);
    
    // Progress arc (pie slice)
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.fill;
      
      final sweepAngle = 2 * 3.14159 * progress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -3.14159 / 2, // Start from top
        sweepAngle,
        true, // Use center
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_PieChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.backgroundColor != backgroundColor ||
           oldDelegate.progressColor != progressColor;
  }
}

/// Custom painter for progress ring around button edge
class _PieProgressRingPainter extends CustomPainter {
  final double progress;
  final Color ringColor;
  final Color backgroundColor;

  _PieProgressRingPainter({
    required this.progress,
    required this.ringColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2; // Slightly inside edge
    final strokeWidth = 3.0;
    
    // Progress arc ring
    if (progress > 0) {
      final ringPaint = Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      
      final sweepAngle = 2 * 3.14159 * progress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -3.14159 / 2, // Start from top
        sweepAngle,
        false,
        ringPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_PieProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.ringColor != ringColor;
  }
}
