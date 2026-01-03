/// Game screen for Nertz Royale

library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui'; // Required for ImageFilter
import 'package:nertz_royale/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/matchmaking_service.dart';

import '../../models/card.dart';
import '../../models/player_state.dart';
import '../../models/game_state.dart';
import '../../engine/move_validator.dart';
import '../../state/game_provider.dart';
import '../../state/economy_provider.dart';
import '../../services/audio_service.dart';
import '../../services/economy_service.dart';
import '../theme/game_theme.dart';
import '../widgets/game_board.dart';
import 'results_screen.dart';

import '../widgets/lobby_overlay.dart';
import 'main_navigation_screen.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> with TickerProviderStateMixin {
  // +1 animation state
  final List<_FloatingScore> _floatingScores = [];
  int _scoreAnimationId = 0;
  
  // Manual phase tracking (Riverpod's ref.listen can't reliably detect transitions when state is mutated)
  GamePhase? _lastSeenPhase;
  bool _sheetScheduled = false;
  int? _oldXp; // For Results screen animation
  int? _newXp; // For Results screen animation
  int? _oldRanked; // For Results screen animation
  int? _newRanked; // For Results screen animation

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

  void _showPlusOneAnimation([PlayingCard? card]) {
    // Don't show +1 for Nertz cards (they get +2 animation)
    if (card != null && card.isNertzOrigin) return;
    final controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    final id = _scoreAnimationId++;
    final floater = _FloatingScore(id: id, controller: controller, text: '+1');
    
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

  void _showPlusTwoAnimation() {
    final controller = AnimationController(
      duration: const Duration(milliseconds: 1200), // Slightly slower/grandier
      vsync: this,
    );
    
    final id = _scoreAnimationId++;
    final floater = _FloatingScore(id: id, controller: controller, text: '+2');
    
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

  /// Generic floating score animation for penalties and custom score displays
  void _showFloatingScore(
    int score, {
    Color? color,
    Alignment? alignment,
    double fontScale = 1.0,
    String? textPrefix,
  }) {
    final controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    final id = _scoreAnimationId++;
    final text = score >= 0 ? '+$score' : '$score';
    final floater = _FloatingScore(
      id: id, 
      controller: controller, 
      text: text,
      alignment: alignment,
      fontScale: fontScale,
      textPrefix: textPrefix,
    );
    
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

    // Check if this move is from the Nertz pile BEFORE executing (as execution modifies state)
    // We do this to trigger the special +2 animation/sound
    bool isNertzMove = false;
    final playerId = ref.read(playerIdProvider);
    final preMoveGameState = ref.read(gameStateProvider);
    
    if (preMoveGameState != null && move.cardId != null) {
       final player = preMoveGameState.getPlayer(playerId);
       if (player != null) {
         final location = player.findCard(move.cardId!);
         if (location != null && location.type == PileType.nertz) {
           isNertzMove = true;
         }
       }
    }

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
      
      // Trigger Nertz Move Effects if applicable
      if (isNertzMove) {
        _showPlusTwoAnimation();
        AudioService().playNertzCard();
      }
    }
    
    
    // Listener in build handles round end checking now
    /*
    final gameState = ref.read(gameStateProvider);
    if (gameState?.phase == GamePhase.roundEnd || 
        gameState?.phase == GamePhase.matchEnd) {
      _showRoundEndSheet();
    }
    */
  }

  void _handleAutoMove(PlayingCard card) {
    final playerId = ref.read(playerIdProvider);
    final success = ref.read(gameStateProvider.notifier).autoMove(card.id, playerId);
    
    if (success) {
      HapticFeedback.mediumImpact();
      
      // Listener handles round end
      /*
      final gameState = ref.read(gameStateProvider);
      if (gameState?.phase == GamePhase.roundEnd || 
          gameState?.phase == GamePhase.matchEnd) {
        _showRoundEndSheet();
      }
      */
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

  // No longer read state internally, assume state is passed or refreshed at call site? 
  // Wait, ref.read(gameStateProvider) is safe if called from listener context or if we just want CURRENT snapshot.
  
  void _showRoundEndSheet() {
    debugPrint('🎬 _showRoundEndSheet CALLED');
    final gameState = ref.read(gameStateProvider);
    final currentPlayerId = ref.read(playerIdProvider);
    if (gameState == null) {
      debugPrint('❌ _showRoundEndSheet: gameState is null, returning');
      return;
    }
    debugPrint('🎬 _showRoundEndSheet: phase=${gameState.phase}');
    
    int coinsEarned = 0;
    int bonusCoins = 0;

    try {
      // Play winner sound if current player won the round (but not match end - that gets applause)
      if (gameState.phase == GamePhase.roundEnd && 
          gameState.roundWinnerId == currentPlayerId) {
        AudioService().playWinner().catchError((e) => debugPrint('Audio error: $e'));
      }
      
      // Award coins ONLY at match end
      if (gameState.phase == GamePhase.matchEnd) {
        final currentPlayer = gameState.players[currentPlayerId];
        if (currentPlayer != null && currentPlayer.scoreTotal > 0) {
          coinsEarned = EconomyService.calculateCoinsEarned(currentPlayer.scoreTotal);
          
          // Calculate Win Bonus (based on rounds played)
          final leader = gameState.leader;
          if (leader != null && leader.id == currentPlayerId) {
             // 10 bonus coins per round played (e.g., 3 rounds = 30 bonus)
             bonusCoins = gameState.maxRounds * 10;
          }
          
          final totalCoins = coinsEarned + bonusCoins;

          if (totalCoins > 0 && EconomyService().isOnline) {
            EconomyService().awardCoins(
              amount: totalCoins,
              source: 'game_reward',
              referenceId: gameState.matchId,
            ).then((_) {
              ref.invalidate(balanceProvider);
            }).catchError((e) {
              debugPrint('Error awarding coins: $e');
            });
          }
        }
      }
    } catch (e, stack) {
      debugPrint('Error preparing round end: $e\n$stack');
    }
    
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true, // Allow full height
      backgroundColor: GameTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _RoundEndSheet(
        gameState: gameState,
        coinsEarned: coinsEarned,
        bonusCoins: bonusCoins,
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
    final gameState = ref.read(gameStateProvider);
    final myId = ref.read(playerIdProvider);
    final leaderboard = gameState?.getLeaderboard() ?? [];
    
    // Ranked Match Logic: Report results
    if (gameState != null && gameState.isRanked && myId != null) {
      final myIndex = leaderboard.indexWhere((p) => p.id == myId);
      if (myIndex != -1) {
        final placement = myIndex + 1;
        final myScore = leaderboard[myIndex].scoreTotal;
        debugPrint('🏆 Reporting Ranked Result: Place #$placement, Score: $myScore');
        MatchmakingService().reportRankedMatchResult(
          placement: placement, 
          totalPoints: myScore
        );
      }
    }
    
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => ResultsScreen(
          oldXp: _oldXp,
          newXp: _newXp,
          leaderboard: leaderboard,
          currentUserId: myId,
          // New Ranked Props
          oldRanked: _oldRanked,
          newRanked: _newRanked,
          isRanked: gameState?.isRanked ?? false,
        ),
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

  void _confirmQuit() async {
    final gameState = ref.read(gameStateProvider);
    final client = ref.read(gameClientProvider);
    
    // Check for Leaver Penalty (Ranked + Playing)
    if (gameState != null && 
        gameState.isRanked && 
        gameState.phase == GamePhase.playing) {
          
      // Report penalty (-20 RP)
      // We don't await this to block UI, just fire and forget if needed, 
      // but waiting ensures it sends before disconnect involves closing socket.
      // Actually, standard is to await.
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator()),
      );
      
      try {
        await MatchmakingService().reportRankedPenalty(20);
        // Send Leave Message to others (so they can trigger Default Win if last)
        client.leaveMatch(gameState.matchId);
        // Wait briefly for message to flush
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        debugPrint('Error during quit sequence: $e');
      } finally {
        if (mounted) Navigator.pop(context); // Close loading
      }
    } else {
      // Non-ranked or not playing - just leave friendly
      if (gameState != null) {
         client.leaveMatch(gameState.matchId);
      }
    }

    if (!mounted) return;
    
    Navigator.pop(context); // Close dialog

    ref.read(gameStateProvider.notifier).reset();
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const MainNavigationScreen(),
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
  }

  @override
  Widget build(BuildContext context) {
    // Listen for game phase changes to handle stats updates
    ref.listen<GameState?>(gameStateProvider, (previous, next) {
      if (next == null || previous == null) return;
      
      debugPrint('🔍 LISTENER: prev.phase=${previous.phase}, next.phase=${next.phase}');
      
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      // if (currentUserId == null) return; // Removed to allow sheet updates without auth
      
      // 1. Detect Round/Match End for XP (Cards in Center)
      if (currentUserId != null &&
          previous.phase == GamePhase.playing && 
          (next.phase == GamePhase.roundEnd || next.phase == GamePhase.matchEnd)) {
         
         final cardsInCenter = next.countPlayerCardsInCenter(currentUserId);
         if (cardsInCenter > 0) {
           SupabaseService().addXP(cardsInCenter);
           debugPrint('⭐ Awarded $cardsInCenter XP for round!');
         }
      }
      
      // 2. Detect Match End for Win/Streak Stats
      if (currentUserId != null &&
          previous.phase != GamePhase.matchEnd && next.phase == GamePhase.matchEnd) {
         final leader = next.leader;
         if (leader != null && leader.id == currentUserId) {
            debugPrint('🏆 Match Won! Updating stats...');
            int? duration;
            if (next.matchStartTime != null) {
              duration = DateTime.now().difference(next.matchStartTime!).inSeconds;
            }
            SupabaseService().incrementWin(matchDurationSeconds: duration);
         } else {
            debugPrint('💔 Match Lost! Resetting streak...');
            SupabaseService().recordLoss();
         }
      }

      // 3. Trigger Round/Match End Sheet
      final wasEnding = previous.phase == GamePhase.roundEnd || previous.phase == GamePhase.matchEnd;
      final isEnding = next.phase == GamePhase.roundEnd || next.phase == GamePhase.matchEnd;
      
      debugPrint('🔍 SHEET CHECK: wasEnding=$wasEnding, isEnding=$isEnding');
      
      if (!wasEnding && isEnding) {
        debugPrint('✅ TRIGGERING SHEET via addPostFrameCallback');
        // Use a post-frame callback to ensure context is valid and prevent build collision
        WidgetsBinding.instance.addPostFrameCallback((_) {
          debugPrint('📋 POST FRAME CALLBACK: mounted=$mounted');
          if (mounted) _showRoundEndSheet();
        });
      }
    });

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

    // MANUAL PHASE DETECTION (bypasses unreliable ref.listen)
    final currentPhase = gameState.phase;
    final previousPhase = _lastSeenPhase;
    _lastSeenPhase = currentPhase;
    
    // Detect transition from playing to round/match end
    final wasPlaying = previousPhase == GamePhase.playing;
    final isEnding = currentPhase == GamePhase.roundEnd || currentPhase == GamePhase.matchEnd;
    
    if (previousPhase != null && wasPlaying && isEnding && !_sheetScheduled) {
      _sheetScheduled = true;
      debugPrint('🎯 MANUAL DETECTION: $previousPhase → $currentPhase, scheduling sheet');
      
      // === XP AND STATS LOGIC ===
      // Important: Use LOCAL playerId for game state lookups, Supabase auth ID for DB writes
      final localPlayerId = ref.read(playerIdProvider);
      final supabaseUserId = Supabase.instance.client.auth.currentUser?.id;
      
      debugPrint('🔑 IDs: localPlayerId=$localPlayerId, supabaseUserId=$supabaseUserId');
      
      // Award XP ONLY at Match End (to show full progress bar animation)
      // Previous per-round logic removed
      
      // Track Win/Loss stats at match end AND award XP
      if (currentPhase == GamePhase.matchEnd && supabaseUserId != null) {
        final localPlayer = gameState.players[localPlayerId];
        final leader = gameState.leader;
        debugPrint('👑 Leader: ${leader?.id}, localPlayerId: $localPlayerId');
        
        // 1. Calculate Rank and Bonus Factors
        
        // A. Rank Multiplier
        // 1st: 100% of score bonus
        // 2nd: 50% of score bonus
        // 3rd: 25% of score bonus
        // 4th: 10% of score bonus

        // TRIGGER PENALTY ANIMATIONS
        if (mounted) {
          int oppIndex = 0;
          final opponents = gameState.activeOpponents(localPlayerId);
          
          for (final opponent in opponents) {
            final penalty = opponent.nertzPile.remaining;
            if (penalty > 0) {
              // Approximate alignment based on index (Row layout)
              // 0 -> Left, 1 -> Center, 2 -> Right
              Alignment alignment = const Alignment(0, -0.6); // Default top center-ish
              
              if (opponents.length == 1) {
                alignment = const Alignment(0, -0.6);
              } else if (opponents.length == 2) {
                alignment = oppIndex == 0 ? const Alignment(-0.5, -0.6) : const Alignment(0.5, -0.6);
              } else if (opponents.length >= 3) {
                 if (oppIndex == 0) alignment = const Alignment(-0.7, -0.6);
                 if (oppIndex == 1) alignment = const Alignment(0, -0.6);
                 if (oppIndex == 2) alignment = const Alignment(0.7, -0.6);
              }
              
              _showFloatingScore(-penalty, color: GameTheme.error, alignment: alignment, fontScale: 1.5);
            }
            oppIndex++;
          }
          
          // Also show for local player if they lost points? 
          // Maybe just center screen slightly lower?
          final myPenalty = localPlayer?.nertzPile.remaining ?? 0;
          if (myPenalty > 0) {
             _showFloatingScore(-myPenalty, color: GameTheme.error, alignment: const Alignment(0, 0.2), fontScale: 1.5, textPrefix: "Penalty: ");
          }
        }
        final leaderboard = gameState.getLeaderboard();
        final myRankIndex = leaderboard.indexWhere((p) => p.id == localPlayerId);
        final myRank = myRankIndex + 1; // 1-based
        
        double rankMultiplier = 0.1;
        if (myRank == 1) rankMultiplier = 1.0;
        else if (myRank == 2) rankMultiplier = 0.5;
        else if (myRank == 3) rankMultiplier = 0.25;

        // B. Game Length Multiplier (Total Rounds Played)
        // 1 Round: 20%
        // 2 Rounds: 50%
        // 3 Rounds: 75%
        // 4 Rounds: 100%
        // 5+ Rounds: 120%
        final totalRounds = gameState.roundNumber;
        double lengthMultiplier = 0.2;
        if (totalRounds == 2) lengthMultiplier = 0.5;
        else if (totalRounds == 3) lengthMultiplier = 0.75;
        else if (totalRounds == 4) lengthMultiplier = 1.0;
        else if (totalRounds >= 5) lengthMultiplier = 1.2;
        
        // 2. Calculate Total XP earned
        // Formula: Base Score + (Base Score * RankMultiplier * LengthMultiplier)
        // Basically: Your score is your base XP. The bonus is a percentage of that score,
        // scaled by how long the game was and how well you did.
        final scoreXp = localPlayer?.scoreTotal ?? 0;
        final xpBonus = (scoreXp * rankMultiplier * lengthMultiplier).round();
        final totalEarnedXp = scoreXp + xpBonus;
        
        debugPrint('⭐ XP Calc: Score($scoreXp) + Bonus($xpBonus) = $totalEarnedXp');
        debugPrint('   Details: Rank #$myRank ($rankMultiplier) x Length $totalRounds ($lengthMultiplier)');

        // 3. Process DB Updates (Async)
        Future.microtask(() async {
           try {
             // A. Get current profile for Old XP and Ranked Points
             final profile = await SupabaseService().getProfile();
             final currentTotalXp = (profile?['total_xp'] as int?) ?? 0;
             final currentRanked = (profile?['ranked_points'] as int?) ?? 1000;
             
             if (mounted) setState(() {
               _oldXp = currentTotalXp;
               _oldRanked = currentRanked;
             });
             
             // Calculate Expected Ranked Points Change (for UI only - DB updated by MatchmakingService)
             if (gameState.isRanked) {
                final leaderboard = gameState.getLeaderboard();
                final myIndex = leaderboard.indexWhere((p) => p.id == localPlayerId);
                if (myIndex != -1) {
                  final placement = myIndex + 1;
                  int bonus = 0;
                  if (placement == 1) bonus = 50;
                  else if (placement == 2) bonus = 25;
                  final myscore = leaderboard[myIndex].scoreTotal;
                  if (mounted) setState(() => _newRanked = currentRanked + myscore + bonus);
                }
             }
             
             // B. Add new XP
             if (totalEarnedXp > 0) {
               await SupabaseService().addXP(totalEarnedXp);
               if (mounted) setState(() => _newXp = currentTotalXp + totalEarnedXp);
               debugPrint('✅ XP Updated: $currentTotalXp -> ${currentTotalXp + totalEarnedXp}');
             }
             
             // C. Update Win/Loss Stats
             if (leader != null && leader.id == localPlayerId) {
               debugPrint('🏆 Match Won! Updating stats...');
               int? duration;
               if (gameState.matchStartTime != null) {
                  duration = DateTime.now().difference(gameState.matchStartTime!).inSeconds;
               }
               await SupabaseService().incrementWin(matchDurationSeconds: duration);
             } else {
               debugPrint('💔 Match Lost! Recording loss...');
               await SupabaseService().recordLoss();
             }
           } catch (e) {
             debugPrint('❌ Error updating end match stats: $e');
           }
        });
      }
      
      // (Win/Loss Stats logic moved inside the async block above)
      // === END XP AND STATS LOGIC ===
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showRoundEndSheet();
          _sheetScheduled = false; // Reset for next round
        }
      });
    }
    
    // Reset tracking when going back to playing (new round started)
    if (currentPhase == GamePhase.playing) {
      _sheetScheduled = false;
    }

    // Check if current player has emptied their Nertz pile
    final currentPlayer = gameState.getPlayer(playerId);
    final hasWonRound = currentPlayer?.nertzPile.isEmpty ?? false;
    final isPlaying = gameState.phase == GamePhase.playing;
    final showNertzButton = hasWonRound && isPlaying;
    
    final backgroundAsset = ref.watch(selectedBackgroundAssetProvider).valueOrNull;

    return Scaffold(
      body: Stack(
        children: [
          // Background Layer
          Container(
            decoration: BoxDecoration(
              gradient: backgroundAsset == null ? GameTheme.backgroundGradient : null,
                  image: backgroundAsset != null ? DecorationImage(
                image: AssetImage(backgroundAsset),
                fit: BoxFit.cover,
              ) : null,
            ),
          ),
          
          // Visibility Overlay (Blur + Tint) for Custom Backgrounds
          if (backgroundAsset != null)
            ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5), // Dreamy blur
                child: Container(
                  color: Colors.black.withValues(alpha: 0.2), // 20% dark tint
                ),
              ),
            ),
          
          Consumer(
            builder: (context, ref, child) {
              // Use the dynamic asset provider that fetches URL from shop_products
              final cardBackAsset = ref.watch(selectedCardBackAssetProvider).valueOrNull ?? 'assets/card_back.png';
              
              return GameBoard(
                gameState: gameState,
                currentPlayerId: playerId,
                style: cardStyle,
                selectedCardBack: cardBackAsset,
                onMove: _handleMove,
                onCenterPilePlaced: _showPlusOneAnimation,
                onVoteReset: () {
                   HapticFeedback.mediumImpact();
                   ref.read(gameStateProvider.notifier).voteForReset();
                },
                onShuffleDeck: () {
                   HapticFeedback.heavyImpact();
                   AudioService().playShuffle();
                   ref.read(gameStateProvider.notifier).shuffleDeck();
                },
                onLeaveMatch: () {
                  ref.read(gameStateProvider.notifier).reset();
                  Navigator.of(context).pushAndRemoveUntil(
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) => const MainNavigationScreen(),
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
              );
            },
          ),
          
          // Lobby Overlay (Show "Get Ready!" for ranked, full lobby for casual)
          if (gameState.phase == GamePhase.lobby)
            gameState.isRanked
                ? _buildGetReadyOverlay()  // Simple "Get Ready!" for ranked
                : LobbyOverlay(
                    matchId: gameState.matchId, 
                    isHost: gameState.hostId == playerId,
                    onClose: () {
                      ref.read(gameStateProvider.notifier).reset();
                      Navigator.of(context).pushAndRemoveUntil(
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) => const MainNavigationScreen(),
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

          // Floating +1 animations
          for (final floater in _floatingScores)
            Positioned.fill(
              child: Align(
                alignment: floater.alignment ?? const Alignment(0, -0.2), // Default slightly above center
                child: AnimatedBuilder(
                  animation: floater.controller,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, -50 * floater.controller.value),
                      child: Opacity(
                        opacity: 1.0 - floater.controller.value,
                        child: Text(
                          "${floater.textPrefix ?? ""}${floater.text}", // Support prefix (e.g. "Penalty: ")
                          style: TextStyle(
                            color: floater.text.startsWith('-')
                                ? GameTheme.error
                                : floater.text == '+2'
                                    ? const Color(0xFFFF9800) // Bright orange for Nertz bonus
                                    : GameTheme.success, 
                            fontSize: (floater.text == '+2' ? 48 : 36) * floater.fontScale,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              const Shadow(
                                color: Colors.black26,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          // NERTZ button overlay when player empties their pile

        ],
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

  /// Simple "Get Ready!" overlay for ranked Quick Matches
  Widget _buildGetReadyOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pulsing animation
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.9, end: 1.1),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
              builder: (context, scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: child,
                );
              },
              onEnd: () => setState(() {}), // Restart animation
              child: const Text(
                'GET READY!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  shadows: [
                    Shadow(color: GameTheme.primary, blurRadius: 20),
                    Shadow(color: Colors.black, blurRadius: 10, offset: Offset(2, 2)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: GameTheme.accent),
            const SizedBox(height: 16),
            Text(
              'Waiting for players to join...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _RoundEndSheet extends StatefulWidget {
  final GameState gameState;
  final VoidCallback onContinue;
  final int coinsEarned;
  final int bonusCoins;

  const _RoundEndSheet({
    required this.gameState,
    required this.onContinue,
    this.coinsEarned = 0,
    this.bonusCoins = 0,
  });

  @override
  State<_RoundEndSheet> createState() => _RoundEndSheetState();
}

class _RoundEndSheetState extends State<_RoundEndSheet> {
  @override
  void initState() {
    super.initState();
    if (widget.gameState.phase == GamePhase.matchEnd) {
      AudioService().playChaChing();
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameState = widget.gameState;
    final isMatchEnd = gameState.phase == GamePhase.matchEnd;
    final leaderboard = gameState.leaderboard;
    
    // Explicitly use passed values
    final coinsEarned = widget.coinsEarned;
    final bonusCoins = widget.bonusCoins;
    
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
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
            
            // Coin Reward Sequence
            if (isMatchEnd) ...[
              const SizedBox(height: 16),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: 0.5 + (0.5 * value),
                    child: Opacity(
                      opacity: value.clamp(0.0, 1.0),
                      child: child,
                    ),
                  );
                },
                child: Column(
                  children: [
                    Image.asset('assets/coin_icon.png', height: 60),
                    const SizedBox(height: 8),
                    Text(
                      '${bonusCoins > 0 ? "+ ${coinsEarned + bonusCoins} Total Coins" : "+ $coinsEarned Coins"}',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(color: Colors.black12, offset: Offset(1,1), blurRadius: 2),
                        ],
                      ),
                    ),
                    if (bonusCoins > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '(Includes $bonusCoins Bonus Coins for Winning!)',
                          style: const TextStyle(
                            color: GameTheme.success,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

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
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${player.scoreThisRound >= 0 ? "+" : ""}${player.scoreThisRound}',
                          style: TextStyle(
                            color: player.scoreThisRound >= 0
                                ? GameTheme.success
                                : GameTheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (player.nertzPile.remaining > 0)
                          Text(
                            '-${player.nertzPile.remaining} Nertz Left',
                            style: const TextStyle(
                              color: GameTheme.error,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
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
                onPressed: widget.onContinue,
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
      ),
    );
  }
}

/// Helper class for floating +1 animation
class _FloatingScore {
  final int id;
  final AnimationController controller;
  final String text;
  
  final Alignment? alignment;
  final double fontScale;
  final String? textPrefix;
  
  _FloatingScore({
    required this.id, 
    required this.controller, 
    this.text = '+1', 
    this.alignment,
    this.fontScale = 1.0,
    this.textPrefix,
  });
}
