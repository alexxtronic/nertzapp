/// Game screen for Nertz Royale

library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/card.dart';
import '../../models/game_state.dart';
import '../../engine/move_validator.dart';
import '../../state/game_provider.dart';
import '../../state/economy_provider.dart';
import '../../services/audio_service.dart';
import '../../services/economy_service.dart';
import '../theme/game_theme.dart';
import '../widgets/game_board.dart';
import 'results_screen.dart';
import 'lobby_screen.dart';
import '../widgets/lobby_overlay.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> with TickerProviderStateMixin {
  // +1 animation state
  final List<_FloatingScore> _floatingScores = [];
  int _scoreAnimationId = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  @override
  void dispose() {
    for (final fs in _floatingScores) {
      fs.controller.dispose();
    }
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  void _showPlusOneAnimation() {
    final controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    final id = _scoreAnimationId++;
    final floater = _FloatingScore(id: id, controller: controller);
    
    setState(() {
      _floatingScores.add(floater);
    });
    
    controller.forward().then((_) {
      controller.dispose();
      setState(() {
        _floatingScores.removeWhere((f) => f.id == id);
      });
    });
  }

  void _handleMove(Move move) {
    final result = ref.read(gameStateProvider.notifier).executeMove(move);
    
    if (!result.isValid) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Invalid move'),
          backgroundColor: GameTheme.error,
          duration: const Duration(seconds: 1),
        ),
      );
    } else {
      HapticFeedback.lightImpact();
    }
    
    final gameState = ref.read(gameStateProvider);
    if (gameState?.phase == GamePhase.roundEnd || 
        gameState?.phase == GamePhase.matchEnd) {
      _showRoundEndSheet();
    }
  }

  void _handleAutoMove(PlayingCard card) {
    final playerId = ref.read(playerIdProvider);
    final success = ref.read(gameStateProvider.notifier).autoMove(card.id, playerId);
    
    if (success) {
      HapticFeedback.mediumImpact();
      
      final gameState = ref.read(gameStateProvider);
      if (gameState?.phase == GamePhase.roundEnd || 
          gameState?.phase == GamePhase.matchEnd) {
        _showRoundEndSheet();
      }
    } else {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No valid moves for this card'),
          backgroundColor: GameTheme.warning,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _showRoundEndSheet() {
    final gameState = ref.read(gameStateProvider);
    final currentPlayerId = ref.read(playerIdProvider);
    if (gameState == null) return;
    
    // Play winner sound if current player won the round (but not match end - that gets applause)
    if (gameState.phase == GamePhase.roundEnd && 
        gameState.roundWinnerId == currentPlayerId) {
      AudioService().playWinner();
    }
    
    // Award coins ONLY at match end, based on total score (1 coin per 10 points)
    if (gameState.phase == GamePhase.matchEnd) {
      final currentPlayer = gameState.players[currentPlayerId];
      if (currentPlayer != null && currentPlayer.scoreTotal > 0) {
        final coinsEarned = EconomyService.calculateCoinsEarned(currentPlayer.scoreTotal);
        if (coinsEarned > 0 && EconomyService().isOnline) {
          EconomyService().awardCoins(
            amount: coinsEarned,
            source: 'game_reward',
            referenceId: gameState.matchId,
          ).then((_) {
            // Refresh balance in providers
            ref.invalidate(balanceProvider);
          });
        }
      }
    }
    
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: GameTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _RoundEndSheet(
        gameState: gameState,
        onContinue: () {
          Navigator.pop(context);
          if (gameState.phase == GamePhase.matchEnd) {
            _goToResults();
          } else {
            ref.read(gameStateProvider.notifier).startNewRound();
          }
        },
      ),
    );
  }

  void _goToResults() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const ResultsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _showPauseMenu() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GameTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'PAUSED',
          style: TextStyle(color: GameTheme.textPrimary),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('RESUME'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _confirmQuit();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: GameTheme.error,
                  side: const BorderSide(color: GameTheme.error),
                ),
                child: const Text('QUIT GAME'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmQuit() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GameTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Quit Game?',
          style: TextStyle(color: GameTheme.textPrimary),
        ),
        content: const Text(
          'Your progress will be lost.',
          style: TextStyle(color: GameTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              ref.read(gameStateProvider.notifier).reset();
              Navigator.of(context).pushAndRemoveUntil(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => const LobbyScreen(),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return FadeTransition(
                      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
                      child: child,
                    );
                  },
                  transitionDuration: const Duration(milliseconds: 300),
                ),
                (route) => false,
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: GameTheme.error,
            ),
            child: const Text('QUIT'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameStateProvider);
    final playerId = ref.watch(playerIdProvider);
    final cardStyle = ref.watch(cardStyleProvider);
    
    if (gameState == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Check if current player has emptied their Nertz pile
    final currentPlayer = gameState.getPlayer(playerId);
    final hasWonRound = currentPlayer?.nertzPile.isEmpty ?? false;
    final isPlaying = gameState.phase == GamePhase.playing;
    final showNertzButton = hasWonRound && isPlaying;
    
    return Scaffold(
      body: Stack(
        children: [
          GameBoard(
            gameState: gameState,
            currentPlayerId: playerId,
            style: cardStyle,
            onMove: _handleMove,
            onCenterPilePlaced: _showPlusOneAnimation,
            onLeaveMatch: () {
              ref.read(gameStateProvider.notifier).reset();
              Navigator.of(context).pushAndRemoveUntil(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => const LobbyScreen(),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return FadeTransition(
                      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
                      child: child,
                    );
                  },
                  transitionDuration: const Duration(milliseconds: 300),
                ),
                (route) => false,
              );
            },
          ),
          
          // Lobby Overlay
          if (gameState.phase == GamePhase.lobby)
             LobbyOverlay(
                matchId: gameState.matchId, 
                isHost: gameState.hostId == playerId
             ),

          // Floating +1 animations
          for (final floater in _floatingScores)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.4,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: floater.controller,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, -50 * floater.controller.value),
                    child: Opacity(
                      opacity: 1.0 - floater.controller.value,
                      child: const Center(
                        child: Text(
                          '+1',
                          style: TextStyle(
                            color: GameTheme.success,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          // NERTZ button overlay when player empties their pile
          if (showNertzButton)
            _buildNertzButtonOverlay(playerId),
        ],
      ),
    );
  }

  Widget _buildNertzButtonOverlay(String playerId) {
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Instruction text
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: GameTheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: GameTheme.softShadow,
              ),
              child: const Text(
                '🎉 TAP THE NERTZ BUTTON! 🎉',
                style: TextStyle(
                  color: GameTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Nertz button
            GestureDetector(
              onTap: () => _callNertz(playerId),
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.5),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/nertz_button.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback if image doesn't load
                    return Container(
                      width: 180,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF4444), Color(0xFFCC0000)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(color: const Color(0xFFFFD700), width: 6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.5),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'NERTZ!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'You emptied your Nertz pile!',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _callNertz(String playerId) {
    // End the round with this player as the winner
    final notifier = ref.read(gameStateProvider.notifier);
    notifier.endRound(playerId);
  }

  void _showSettingsMenu() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white, // Opaque for readability
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(color: GameTheme.textPrimary),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('Sound Effects', style: TextStyle(color: GameTheme.textPrimary)),
              value: true, // TODO: Connect to actual state
              onChanged: (value) {
                // TODO: Toggle sound
              },
              activeColor: GameTheme.primary,
            ),
            SwitchListTile(
              title: const Text('Music', style: TextStyle(color: GameTheme.textPrimary)),
              value: true, // TODO: Connect to actual state
              onChanged: (value) {
                // TODO: Toggle music
              },
              activeColor: GameTheme.primary,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _confirmQuit();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: GameTheme.error,
                  side: const BorderSide(color: GameTheme.error),
                ),
                child: const Text('LEAVE GAME'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }
}

class _RoundEndSheet extends StatelessWidget {
  final GameState gameState;
  final VoidCallback onContinue;

  const _RoundEndSheet({
    required this.gameState,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final isMatchEnd = gameState.phase == GamePhase.matchEnd;
    final leaderboard = gameState.leaderboard;
    
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: GameTheme.surfaceLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isMatchEnd ? '🏆 MATCH OVER!' : 'Round ${gameState.roundNumber} Complete',
            style: TextStyle(
              color: GameTheme.textPrimary,
              fontSize: isMatchEnd ? 28 : 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (gameState.roundWinnerId != null)
            Text(
              '${gameState.players[gameState.roundWinnerId]?.displayName ?? "Someone"} emptied their Nertz pile!',
              style: const TextStyle(color: GameTheme.textSecondary),
            ),
          const SizedBox(height: 24),
          ...leaderboard.asMap().entries.map((entry) {
            final index = entry.key;
            final player = entry.value;
            final isFirst = index == 0;
            
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isFirst
                    ? GameTheme.primary.withValues(alpha: 0.2)
                    : GameTheme.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: isFirst
                    ? Border.all(color: GameTheme.primary, width: 2)
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isFirst ? GameTheme.primary : GameTheme.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: isFirst ? Colors.white : GameTheme.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      player.displayName,
                      style: const TextStyle(
                        color: GameTheme.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    '${player.scoreThisRound >= 0 ? "+" : ""}${player.scoreThisRound}',
                    style: TextStyle(
                      color: player.scoreThisRound >= 0
                          ? GameTheme.success
                          : GameTheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${player.scoreTotal}',
                    style: const TextStyle(
                      color: GameTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onContinue,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                isMatchEnd ? 'VIEW RESULTS' : 'NEXT ROUND',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

/// Helper class for floating +1 animation
class _FloatingScore {
  final int id;
  final AnimationController controller;
  
  _FloatingScore({required this.id, required this.controller});
}
