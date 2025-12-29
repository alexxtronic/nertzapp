/// Game settings dialog (offline mode)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nertz_royale/models/bot_difficulty.dart';
import 'package:nertz_royale/state/bot_difficulty_provider.dart';
import '../theme/game_theme.dart';

class BotDifficultyDialog extends ConsumerWidget {
  const BotDifficultyDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentDifficulty = ref.watch(botDifficultyProvider);
    final currentPoints = ref.watch(pointsToWinProvider);
    final currentBotCount = ref.watch(botCountProvider);
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              GameTheme.background,
              GameTheme.background.withValues(alpha: 0.95),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: GameTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.settings,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Game Settings',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: GameTheme.textPrimary,
                            ),
                          ),
                          Text(
                            'Customize your offline game',
                            style: TextStyle(
                              fontSize: 14,
                              color: GameTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: GameTheme.textSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              
              // Points to Win Section
              _buildSectionHeader('🏆 Points to Win'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [50, 100, 150].map((points) {
                    final isSelected = points == currentPoints;
                    return _buildPointsChip(
                      context, ref, points, isSelected,
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
              
              // Bot Count Section
              _buildSectionHeader('🤖 Number of Bots'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [1, 2, 3].map((count) {
                    final isSelected = count == currentBotCount;
                    return _buildBotCountChip(
                      context, ref, count, isSelected,
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
              
              // Bot Difficulty Section
              _buildSectionHeader('⚡ Bot Difficulty'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: BotDifficulty.values.map((difficulty) {
                    final isSelected = difficulty == currentDifficulty;
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            ref.read(botDifficultyProvider.notifier).state = difficulty;
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? GameTheme.primaryGradient
                                  : LinearGradient(
                                      colors: [
                                        Colors.white.withValues(alpha: 0.05),
                                        Colors.white.withValues(alpha: 0.02),
                                      ],
                                    ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.white.withValues(alpha: 0.3)
                                    : Colors.white.withValues(alpha: 0.1),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  difficulty.emoji,
                                  style: const TextStyle(fontSize: 28),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        difficulty.displayName,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? Colors.white
                                              : GameTheme.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        difficulty.description,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isSelected
                                              ? Colors.white.withValues(alpha: 0.9)
                                              : GameTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              
              // Done Button
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GameTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 16,
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
    );
  }
  
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: GameTheme.textPrimary,
          ),
        ),
      ),
    );
  }
  
  Widget _buildPointsChip(BuildContext context, WidgetRef ref, int points, bool isSelected) {
    return GestureDetector(
      onTap: () {
        ref.read(pointsToWinProvider.notifier).state = points;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected ? GameTheme.primaryGradient : null,
          color: isSelected ? null : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected 
                ? Colors.white.withValues(alpha: 0.3) 
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          '$points',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : GameTheme.textPrimary,
          ),
        ),
      ),
    );
  }
  
  Widget _buildBotCountChip(BuildContext context, WidgetRef ref, int count, bool isSelected) {
    return GestureDetector(
      onTap: () {
        ref.read(botCountProvider.notifier).state = count;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected ? GameTheme.primaryGradient : null,
          color: isSelected ? null : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected 
                ? Colors.white.withValues(alpha: 0.3) 
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          '$count',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : GameTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}
