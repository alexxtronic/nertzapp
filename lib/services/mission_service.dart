/// Mission Service
/// 
/// Handles daily missions:
/// - Fetch/assign daily missions
/// - Track progress on mission objectives
/// - Claim rewards

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Mission types that can be tracked
enum MissionType {
  winGames,
  playGames,
  challengeFriend,
  fastWin,
  nertzCalls,
}

extension MissionTypeExtension on MissionType {
  String get dbValue {
    switch (this) {
      case MissionType.winGames: return 'win_games';
      case MissionType.playGames: return 'play_games';
      case MissionType.challengeFriend: return 'challenge_friend';
      case MissionType.fastWin: return 'fast_win';
      case MissionType.nertzCalls: return 'nertz_calls';
    }
  }
}

/// User mission model
class UserMission {
  final String id;
  final String missionId;
  final String name;
  final String description;
  final String icon;
  final int rewardCoins;
  final int target;
  final int progress;
  final bool isCompleted;
  final bool isClaimed;
  final DateTime assignedAt;

  const UserMission({
    required this.id,
    required this.missionId,
    required this.name,
    required this.description,
    required this.icon,
    required this.rewardCoins,
    required this.target,
    required this.progress,
    required this.isCompleted,
    required this.isClaimed,
    required this.assignedAt,
  });

  double get progressPercent => (progress / target).clamp(0.0, 1.0);

  factory UserMission.fromJson(Map<String, dynamic> json) {
    final mission = json['mission'] ?? json;
    return UserMission(
      id: json['id'] as String,
      missionId: json['mission_id'] as String,
      name: mission['name'] as String? ?? 'Unknown Mission',
      description: mission['description'] as String? ?? '',
      icon: mission['icon'] as String? ?? 'star',
      rewardCoins: mission['reward_coins'] as int? ?? 0,
      target: mission['target'] as int? ?? 1,
      progress: json['progress'] as int? ?? 0,
      isCompleted: json['is_completed'] as bool? ?? false,
      isClaimed: json['is_claimed'] as bool? ?? false,
      assignedAt: DateTime.parse(json['assigned_at'] as String),
    );
  }
}

class MissionService {
  static final MissionService _instance = MissionService._internal();
  factory MissionService() => _instance;
  MissionService._internal();

  final _supabase = Supabase.instance.client;
  
  String? get _currentUserId => _supabase.auth.currentUser?.id;

  /// Get today's missions (assigns if needed)
  Future<List<UserMission>> getDailyMissions() async {
    if (_currentUserId == null) return [];
    
    try {
      // Call the assign function (returns existing or creates new)
      final response = await _supabase
          .rpc('assign_daily_missions', params: {'p_user_id': _currentUserId});
      
      if (response == null || (response as List).isEmpty) {
        // Fallback: fetch manually
        return _fetchTodaysMissions();
      }
      
      // Now fetch with mission details
      return _fetchTodaysMissions();
    } catch (e) {
      debugPrint('Error getting daily missions: $e');
      return _fetchTodaysMissions();
    }
  }

  Future<List<UserMission>> _fetchTodaysMissions() async {
    if (_currentUserId == null) return [];
    
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      
      final response = await _supabase
          .from('user_missions')
          .select('''
            id, mission_id, progress, is_completed, is_claimed, assigned_at,
            mission:missions(name, description, icon, reward_coins, target, mission_type)
          ''')
          .eq('user_id', _currentUserId!)
          .eq('assigned_at', today);
      
      return (response as List)
          .map((json) => UserMission.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error fetching missions: $e');
      return [];
    }
  }

  /// Update mission progress for a specific type
  Future<void> trackProgress(MissionType type, {int increment = 1}) async {
    if (_currentUserId == null) return;
    
    try {
      await _supabase.rpc('update_mission_progress', params: {
        'p_user_id': _currentUserId,
        'p_mission_type': type.dbValue,
        'p_increment': increment,
      });
      
      debugPrint('📊 Mission progress updated: ${type.dbValue} +$increment');
    } catch (e) {
      debugPrint('Error updating mission progress: $e');
    }
  }

  /// Claim reward for completed mission
  Future<int> claimReward(String userMissionId) async {
    try {
      final result = await _supabase.rpc('claim_mission_reward', params: {
        'p_mission_id': userMissionId,
      });
      
      final reward = result as int? ?? 0;
      if (reward > 0) {
        debugPrint('🎁 Claimed $reward coins!');
      }
      return reward;
    } catch (e) {
      debugPrint('Error claiming reward: $e');
      return 0;
    }
  }

  /// Convenience methods for common tracking

  /// Call when user wins a game
  Future<void> trackWin({int? durationSeconds}) async {
    await trackProgress(MissionType.winGames);
    await trackProgress(MissionType.playGames);
    
    // Check for fast win (under 2 minutes = 120 seconds)
    if (durationSeconds != null && durationSeconds < 120) {
      await trackProgress(MissionType.fastWin);
    }
  }

  /// Call when user plays a game (even if lost)
  Future<void> trackGamePlayed() async {
    await trackProgress(MissionType.playGames);
  }

  /// Call when user challenges a friend
  Future<void> trackFriendChallenge() async {
    await trackProgress(MissionType.challengeFriend);
  }

  /// Call when user calls Nertz
  Future<void> trackNertzCall() async {
    await trackProgress(MissionType.nertzCalls);
  }
}
