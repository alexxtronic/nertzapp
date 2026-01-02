/// Results screen for Nertz Royale

library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/game_provider.dart';
import '../theme/game_theme.dart';
import 'main_navigation_screen.dart';
import 'game_screen.dart';

import 'package:nertz_royale/services/audio_service.dart';
import 'package:nertz_royale/models/player_state.dart';

class ResultsScreen extends ConsumerStatefulWidget {
  final int? oldXp;
  final int? newXp;
  final int? oldRanked;
  final int? newRanked;
  final bool isRanked;
  final List<PlayerState> leaderboard;
  final String currentUserId;

  const ResultsScreen({
    super.key, 
    this.oldXp, 
    this.newXp,
    this.oldRanked,
    this.newRanked,
    this.isRanked = false,
    required this.leaderboard,
    required this.currentUserId,
  });

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  @override
  void initState() {
    super.initState();
    // Check for rank up and play sound
    if (widget.oldXp != null && widget.newXp != null) {
      if (_hasRankedUp(widget.oldXp!, widget.newXp!)) {
        AudioService().playApplause();
      }
    }
  }

  bool _hasRankedUp(int oldXp, int newXp) {
    String getRankName(int xp) {
      if (xp < 1000) return 'Bronze';
      if (xp < 2500) return 'Silver';
      if (xp < 5000) return 'Gold';
      return 'Platinum';
    }
    return getRankName(oldXp) != getRankName(newXp);
  }

  @override
  Widget build(BuildContext context) {
    // Use passed data instead of watching provider (which might be null)
    final leaderboard = widget.leaderboard;
    final currentPlayerId = widget.currentUserId;
    
    debugPrint('📊 RESULTS: leaderboard.length=${leaderboard.length}');
    
    if (leaderboard.isEmpty) {
      debugPrint('❌ RESULTS: Showing empty state - leaderboard empty? true');
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: GameTheme.backgroundGradient,
          ),
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: GameTheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.leaderboard_outlined,
                      size: 48,
                      color: GameTheme.primary.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No results yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: GameTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Complete a game to see your results',
                    style: TextStyle(
                      fontSize: 14,
                      color: GameTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    
    final winner = leaderboard.first;
    final isCurrentPlayerWinner = winner.id == currentPlayerId;
    final currentPlayerRank = leaderboard.indexWhere((p) => p.id == currentPlayerId) + 1;
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: GameTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              _buildWinnerSection(winner, isCurrentPlayerWinner),
              // Show Rank Progress for Ranked Games, otherwise XP Progress
              if (widget.isRanked && widget.oldRanked != null && widget.newRanked != null) ...[
                 const SizedBox(height: 16),
                 _buildRankedProgressBar(widget.oldRanked!, widget.newRanked!),
              ] else if (widget.oldXp != null && widget.newXp != null) ...[
                 const SizedBox(height: 16),
                 _buildXpProgressBar(widget.oldXp!, widget.newXp!),
              ],
              const SizedBox(height: 16),
              if (!isCurrentPlayerWinner)
                _buildYourResult(currentPlayerRank, leaderboard.length),
              const SizedBox(height: 16),
              Expanded(
                child: _buildLeaderboard(leaderboard, currentPlayerId),
              ),
              const SizedBox(height: 16),
              _buildActions(context, ref),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWinnerSection(PlayerState player, bool isYou) {
    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 800),
          curve: Curves.elasticOut,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: child,
            );
          },
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Center(
              child: Text(
                '🏆',
                style: TextStyle(fontSize: 56),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          isYou ? 'YOU WON!' : 'WINNER',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
            color: isYou ? GameTheme.success : GameTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          player.displayName,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: GameTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(
            gradient: GameTheme.primaryGradient,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${player.scoreTotal} POINTS',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildYourResult(int rank, int total) {
    String message;
    IconData icon;
    Color color;
    
    if (rank == 2) {
      message = 'So close! You came in 2nd!';
      icon = Icons.emoji_events;
      color = const Color(0xFFC0C0C0);
    } else if (rank == 3) {
      message = 'Great job! You finished 3rd!';
      icon = Icons.emoji_events;
      color = const Color(0xFFCD7F32);
    } else {
      message = 'You finished #$rank of $total';
      icon = Icons.sports_score;
      color = GameTheme.textSecondary;
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GameTheme.surfaceLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Text(
            message,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboard(List<PlayerState> players, String currentPlayerId) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GameTheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FINAL STANDINGS',
            style: TextStyle(
              color: GameTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: players.length,
              itemBuilder: (context, index) {
                final player = players[index];
                final isCurrentPlayer = player.id == currentPlayerId;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isCurrentPlayer
                        ? GameTheme.primary.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: isCurrentPlayer
                        ? Border.all(color: GameTheme.primary.withValues(alpha: 0.5))
                        : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: index == 0
                              ? const Color(0xFFFFD700)
                              : index == 1
                                  ? const Color(0xFFC0C0C0)
                                  : index == 2
                                      ? const Color(0xFFCD7F32)
                                      : GameTheme.surfaceLight,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: index < 3 ? Colors.black : GameTheme.textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          player.displayName + (isCurrentPlayer ? ' (You)' : ''),
                          style: TextStyle(
                            color: GameTheme.textPrimary,
                            fontWeight: isCurrentPlayer ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
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
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
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
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('MAIN MENU'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                ref.read(gameStateProvider.notifier).createLocalGame();
                Navigator.of(context).pushReplacement(
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => const GameScreen(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      return FadeTransition(
                        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
                        child: child,
                      );
                    },
                    transitionDuration: const Duration(milliseconds: 300),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('PLAY AGAIN'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankedProgressBar(int oldPoints, int newPoints) {
    // Ranked Thresholds (Matching DB logic)
    // Bronze: 0-499
    // Silver: 500-999
    // Gold: 1000-2499
    // Platinum: 2500-4999
    // Master: 5000-7499
    // Legend: 7500+

    String getTierName(int points) {
      if (points < 500) return 'Bronze';
      if (points < 1000) return 'Silver';
      if (points < 2500) return 'Gold';
      if (points < 5000) return 'Platinum';
      if (points < 7500) return 'Master';
      return 'Legend';
    }

    Color getRankColor(int points) {
      if (points < 500) return const Color(0xFFCD7F32); // Bronze
      if (points < 1000) return const Color(0xFFC0C0C0); // Silver
      if (points < 2500) return const Color(0xFFFFD700); // Gold
      if (points < 5000) return const Color(0xFFE5E4E2); // Platinum
      if (points < 7500) return Colors.deepPurpleAccent; // Master
      return Colors.redAccent; // Legend
    }

    int getTierStart(int points) {
      if (points < 500) return 0;
      if (points < 1000) return 500;
      if (points < 2500) return 1000;
      if (points < 5000) return 2500;
      if (points < 7500) return 5000;
      return 7500;
    }
    
    int getNextTierStart(int points) {
      if (points < 500) return 500;
      if (points < 1000) return 1000;
      if (points < 2500) return 2500;
      if (points < 5000) return 5000;
      if (points < 7500) return 7500;
      return 100000; // Cap
    }

    // Roman Numerals for sub-tiers (V, IV, III, II, I)
    String getSubTier(int points) {
      if (points >= 7500) return ''; // Legend has no sub-tiers
      
      final start = getTierStart(points);
      final end = getNextTierStart(points);
      final range = end - start;
      final step = range / 5;
      final offset = points - start;
      
      if (offset < step) return 'V';
      if (offset < step * 2) return 'IV';
      if (offset < step * 3) return 'III';
      if (offset < step * 4) return 'II';
      return 'I';
    }
    
    final currentTier = getTierName(newPoints);
    final subTier = getSubTier(newPoints);
    final fullName = '$currentTier $subTier'.trim();
    final rankColor = getRankColor(newPoints);
    
    final startThreshold = getTierStart(newPoints);
    final nextThreshold = getNextTierStart(newPoints);
    final totalRange = nextThreshold - startThreshold;
    
    final oldProgress = (oldPoints - startThreshold) / totalRange;
    final progress = (newPoints - startThreshold) / totalRange;
    
    final pointsGained = newPoints - oldPoints;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.redAccent, Colors.orangeAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.redAccent.withValues(alpha: 0.4),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(2), // 2px border width
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Trophy Icon Section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: rankColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: rankColor, width: 2),
                  ),
                  child: Icon(
                    Icons.emoji_events_rounded,
                    color: rankColor,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                // Text Section
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RANKED RATING: ${fullName.toUpperCase()}',
                        style: TextStyle(
                          color: GameTheme.textSecondary.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '$newPoints',
                            style: const TextStyle(
                              color: Colors.black, // Dark text on white bg
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (pointsGained > 0) ...[
                            const SizedBox(width: 8),
                            Text(
                              '(+$pointsGained)',
                              style: const TextStyle(
                                color: Colors.green,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Progress Bar
            Stack(
              children: [
                // Background Bar
                Container(
                  height: 12, // Slightly thinner for elegance
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                // Progress Bar Animation
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: oldProgress.clamp(0.0, 1.0), end: progress.clamp(0.0, 1.0)),
                  duration: const Duration(seconds: 2),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) => FractionallySizedBox(
                    widthFactor: value,
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Colors.redAccent, Colors.orangeAccent]),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                           BoxShadow(color: Colors.redAccent.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                 Text(
                   '${(progress * 100).toInt()}%',
                   style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.bold)
                 ),
                 if (newPoints < 7500)
                   Text(
                     '${nextThreshold - newPoints} RP to next tier', 
                     style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w500)
                   ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildXpProgressBar(int oldXp, int newXp) {
    // Rank Logic
    // Bronze: 0-999, Silver: 1000-2499, Gold: 2500-4999, Platinum: 5000+
    int getNextRankThreshold(int xp) {
      if (xp < 1000) return 1000;
      if (xp < 2500) return 2500;
      if (xp < 5000) return 5000;
      if (xp < 10000) return 10000;
      if (xp < 25000) return 25000;
      if (xp < 75000) return 75000;
      if (xp < 150000) return 150000;
      return 1000000; // Legend cap (or infinite)
    }
    
    int getStartRankThreshold(int xp) {
      if (xp < 1000) return 0;
      if (xp < 2500) return 1000;
      if (xp < 5000) return 2500;
      if (xp < 10000) return 5000;
      if (xp < 25000) return 10000;
      if (xp < 75000) return 25000;
      if (xp < 150000) return 75000;
      return 150000;
    }
    
    String getRankName(int xp) {
      if (xp < 1000) return 'Level 1';
      if (xp < 2500) return 'Level 2';
      if (xp < 5000) return 'Level 3';
      if (xp < 10000) return 'Level 4';
      if (xp < 25000) return 'Level 5';
      if (xp < 75000) return 'Level 6';
      if (xp < 150000) return 'Level 7';
      return 'Max Level';
    }

    final startThreshold = getStartRankThreshold(newXp);
    final nextThreshold = getNextRankThreshold(newXp);
    final rankName = getRankName(newXp);
    
    // Calculate progress normalized to current rank bracket
    final totalRange = nextThreshold - startThreshold;
    final progress = (newXp - startThreshold) / totalRange;
    final oldProgress = (oldXp - startThreshold) / totalRange;
    
    final didRankUp = getRankName(oldXp) != rankName;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: GameTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: didRankUp ? GameTheme.accent : Colors.transparent, width: 2),
        boxShadow: didRankUp ? [
          BoxShadow(color: GameTheme.accent.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 2)
        ] : null,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(didRankUp ? 'RANK UP!' : 'RANK PROGRESS', style: TextStyle(color: didRankUp ? GameTheme.accent : GameTheme.textSecondary, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              Text('$newXp XP', style: const TextStyle(fontWeight: FontWeight.bold, color: GameTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 16),
          Stack(
            children: [
              // Background Bar
              Container(
                height: 16,
                decoration: BoxDecoration(
                  color: GameTheme.textSecondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              // Filter Bar Animation
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: oldProgress.clamp(0.0, 1.0), end: progress.clamp(0.0, 1.0)),
                duration: const Duration(seconds: 2),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) => FractionallySizedBox(
                  widthFactor: value,
                  child: Container(
                    height: 16,
                    decoration: BoxDecoration(
                      gradient: GameTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                         BoxShadow(color: GameTheme.primary.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2))
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(rankName, style: const TextStyle(fontWeight: FontWeight.bold, color: GameTheme.textPrimary)),
              Text('${nextThreshold - newXp} XP to next rank', style: const TextStyle(color: GameTheme.textSecondary, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
