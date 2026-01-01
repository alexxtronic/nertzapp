/// Missions Tab
/// 
/// Daily missions with coin rewards:
/// - List of 3 daily missions
/// - Progress tracking
/// - Claim button when complete

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/game_theme.dart';

/// Mission model
class Mission {
  final String id;
  final String title;
  final String description;
  final int rewardCoins;
  final int target;
  final int progress;
  final bool claimed;
  final IconData icon;

  const Mission({
    required this.id,
    required this.title,
    required this.description,
    required this.rewardCoins,
    required this.target,
    this.progress = 0,
    this.claimed = false,
    this.icon = Icons.star,
  });

  bool get isComplete => progress >= target;
  double get progressPercent => (progress / target).clamp(0.0, 1.0);
}

/// Sample daily missions (will be backend-driven later)
final dailyMissionsProvider = StateProvider<List<Mission>>((ref) => [
  const Mission(
    id: 'win_1',
    title: 'Quick Victory',
    description: 'Win 1 Nertz game',
    rewardCoins: 20,
    target: 1,
    progress: 0,
    icon: Icons.emoji_events,
  ),
  const Mission(
    id: 'win_3',
    title: 'Triple Threat',
    description: 'Win 3 Nertz games',
    rewardCoins: 50,
    target: 3,
    progress: 1, // Example: 1 done
    icon: Icons.workspace_premium,
  ),
  const Mission(
    id: 'win_5',
    title: 'Nertz Champion',
    description: 'Win 5 Nertz games',
    rewardCoins: 100,
    target: 5,
    progress: 2, // Example: 2 done
    icon: Icons.military_tech,
  ),
]);

class MissionsTab extends ConsumerWidget {
  const MissionsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missions = ref.watch(dailyMissionsProvider);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          
          // Header
          Row(
            children: [
              const Icon(Icons.local_fire_department, color: Color(0xFFFF6B35), size: 28),
              const SizedBox(width: 10),
              const Text(
                'Daily Missions',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: GameTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: GameTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Resets in 12h',
                  style: TextStyle(
                    color: GameTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Complete missions to earn coins!',
            style: TextStyle(
              color: GameTheme.textSecondary.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          
          // Mission cards
          ...missions.map((mission) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _MissionCard(mission: mission),
          )),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  final Mission mission;
  
  const _MissionCard({required this.mission});

  @override
  Widget build(BuildContext context) {
    final isComplete = mission.isComplete;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isComplete ? GameTheme.success.withOpacity(0.5) : GameTheme.glassBorder,
          width: isComplete ? 2 : 1,
        ),
        boxShadow: GameTheme.softShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isComplete ? GameTheme.success : GameTheme.primary).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                mission.icon,
                color: isComplete ? GameTheme.success : GameTheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mission.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: GameTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    mission.description,
                    style: TextStyle(
                      color: GameTheme.textSecondary.withOpacity(0.8),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: mission.progressPercent,
                      backgroundColor: GameTheme.glassBorder,
                      valueColor: AlwaysStoppedAnimation(
                        isComplete ? GameTheme.success : GameTheme.primary,
                      ),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${mission.progress}/${mission.target}',
                    style: TextStyle(
                      color: GameTheme.textSecondary.withOpacity(0.6),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            
            // Reward / Claim button
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isComplete 
                        ? GameTheme.success 
                        : const Color(0xFFFFD700).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isComplete ? Icons.check : Icons.monetization_on,
                        size: 16,
                        color: isComplete ? Colors.white : const Color(0xFFFFD700),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isComplete ? 'Claim' : '+${mission.rewardCoins}',
                        style: TextStyle(
                          color: isComplete ? Colors.white : const Color(0xFFB8860B),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
