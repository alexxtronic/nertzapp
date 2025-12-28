/// Results screen for Nertz Royale

library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/game_provider.dart';
import '../theme/game_theme.dart';
import 'lobby_screen.dart';
import 'game_screen.dart';

class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameStateProvider);
    final leaderboard = ref.watch(leaderboardProvider);
    final currentPlayerId = ref.watch(playerIdProvider);
    
    if (gameState == null || leaderboard.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('No results available')),
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
              const SizedBox(height: 40),
              _buildWinnerSection(winner, isCurrentPlayerWinner),
              const SizedBox(height: 32),
              if (!isCurrentPlayerWinner)
                _buildYourResult(currentPlayerRank, leaderboard.length),
              const SizedBox(height: 24),
              Expanded(
                child: _buildLeaderboard(leaderboard, currentPlayerId),
              ),
              _buildActions(context, ref),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWinnerSection(player, bool isYou) {
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

  Widget _buildLeaderboard(List players, String currentPlayerId) {
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
                  MaterialPageRoute(builder: (_) => const LobbyScreen()),
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
                  MaterialPageRoute(builder: (_) => const GameScreen()),
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
}
