/// Missions Tab
/// 
/// Daily missions with coin rewards:
/// - List of 3 daily missions
/// - Progress tracking
/// - Claim button when complete

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/game_theme.dart';
import '../../services/mission_service.dart';
import '../widgets/currency_display.dart'; // For reward animation

// Mission model removed - using UserMission from service

/// Provider for daily missions
final dailyMissionsProvider = FutureProvider<List<UserMission>>((ref) async {
  return await MissionService().getDailyMissions();
});

class MissionsTab extends ConsumerStatefulWidget {
  const MissionsTab({super.key});

  @override
  ConsumerState<MissionsTab> createState() => _MissionsTabState();
}

class _MissionsTabState extends ConsumerState<MissionsTab> {
  Future<void> _handleClaim(UserMission mission) async {
    if (!mission.isCompleted || mission.isClaimed) return;
    
    // Optimistic update handled by service call + refresh
    final reward = await MissionService().claimReward(mission.id);
    
    if (reward > 0 && mounted) {
      // Refresh missions list
      ref.refresh(dailyMissionsProvider);
      
      // Show reward popup
      showDialog(
        context: context,
        barrierColor: Colors.black45,
        builder: (_) => Center(
          child: CurrencyRewardPopup(
            amount: reward,
            onComplete: () {
              Navigator.of(context).pop();
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final missionsAsync = ref.watch(dailyMissionsProvider);
    
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
          missionsAsync.when(
            data: (missions) {
              if (missions.isEmpty) {
                return const Center(child: Text("No missions available today"));
              }
              return Column(
                children: missions.map((mission) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _MissionCard(
                    mission: mission, 
                    onClaim: () => _handleClaim(mission),
                  ),
                )).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          ),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  final UserMission mission;
  final VoidCallback onClaim;
  
  const _MissionCard({
    required this.mission,
    required this.onClaim,
  });

  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'emoji_events': return Icons.emoji_events;
      case 'workspace_premium': return Icons.workspace_premium;
      case 'military_tech': return Icons.military_tech;
      case 'bolt': return Icons.bolt;
      case 'people': return Icons.people;
      case 'campaign': return Icons.campaign;
      default: return Icons.star;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isComplete = mission.isCompleted;
    final isClaimed = mission.isClaimed;
    final iconData = _getIcon(mission.icon);
    
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
                iconData,
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
                    mission.name,
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
                    color: isClaimed 
                        ? Colors.grey.withOpacity(0.2)
                        : isComplete 
                            ? GameTheme.success 
                            : const Color(0xFFFFD700).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: isComplete && !isClaimed ? onClaim : null,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isClaimed ? Icons.check_circle : (isComplete ? Icons.check : Icons.monetization_on),
                              size: 16,
                              color: isClaimed 
                                  ? Colors.grey 
                                  : (isComplete ? Colors.white : const Color(0xFFFFD700)),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isClaimed ? 'Done' : (isComplete ? 'Claim' : '+${mission.rewardCoins}'),
                              style: TextStyle(
                                color: isClaimed 
                                    ? Colors.grey 
                                    : (isComplete ? Colors.white : const Color(0xFFB8860B)),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
