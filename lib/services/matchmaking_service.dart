/// Service to handle Ranked Matchmaking
/// 
/// Handles:
/// - Joining/Leaving matchmaking queue
/// - Finding opponents via client-side polling (serverless approach)
/// - Calculating ELO updates

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../ui/theme/game_theme.dart';

/// Rank Tier definitions
enum RankTier {
  bronze(0, 'Bronze', Color(0xFFCD7F32)),
  silver(500, 'Silver', Color(0xFFC0C0C0)),
  gold(1000, 'Gold', Color(0xFFFFD700)),
  platinum(2500, 'Platinum', Color(0xFF00CED1)),
  master(5000, 'Master', Color(0xFF9B59B6)),
  legend(7500, 'Legend', Color(0xFFFF4500));

  final int minPoints;
  final String label;
  final Color color;
  const RankTier(this.minPoints, this.label, this.color);
  
  static RankTier fromPoints(int points) {
    if (points >= legend.minPoints) return legend;
    if (points >= master.minPoints) return master;
    if (points >= platinum.minPoints) return platinum;
    if (points >= gold.minPoints) return gold;
    if (points >= silver.minPoints) return silver;
    return bronze;
  }
  
  // Calculate sub-rank (V to I) based on points within tier
  String getSubRank(int points) {
    if (this == legend) return ''; // Legend has no sub-ranks
    
    // Determine next tier threshold
    int nextTierPoints;
    switch (this) {
      case RankTier.bronze: nextTierPoints = RankTier.silver.minPoints; break;
      case RankTier.silver: nextTierPoints = RankTier.gold.minPoints; break;
      case RankTier.gold: nextTierPoints = RankTier.platinum.minPoints; break;
      case RankTier.platinum: nextTierPoints = RankTier.master.minPoints; break;
      case RankTier.master: nextTierPoints = RankTier.legend.minPoints; break;
      default: return '';
    }
    
    int range = nextTierPoints - minPoints;
    int pointsInTier = points - minPoints;
    
    // 5 divisions
    double progress = pointsInTier / range;
    
    if (progress < 0.2) return 'V';
    if (progress < 0.4) return 'IV';
    if (progress < 0.6) return 'III';
    if (progress < 0.8) return 'II';
    return 'I';
  }
}

class MatchmakingService {
  static final MatchmakingService _instance = MatchmakingService._internal();
  factory MatchmakingService() => _instance;
  MatchmakingService._internal();

  final _supabase = Supabase.instance.client;
  final _uuid = const Uuid();
  
  String? get _currentUserId => _supabase.auth.currentUser?.id;

  /// Join the matchmaking queue
  Future<void> joinQueue() async {
    if (_currentUserId == null) throw Exception('Not logged in');

    try {
      // Get current profile for points
      final profile = await _supabase
          .from('profiles')
          .select('username, avatar_url, ranked_points')
          .eq('id', _currentUserId!)
          .single();

      final points = profile['ranked_points'] as int? ?? 1000;
      final username = profile['username'] as String? ?? 'Player';
      final avatarUrl = profile['avatar_url'] as String?;

      // Clean up any old entry
      await leaveQueue();

      // Insert into queue
      await _supabase.from('matchmaking_queue').insert({
        'user_id': _currentUserId,
        'username': username,
        'avatar_url': avatarUrl,
        'ranked_points': points,
        'status': 'searching',
      });
      
      debugPrint('🔍 Joined matchmaking queue ($points ELO)');
    } catch (e) {
      debugPrint('Error joining queue: $e');
      rethrow;
    }
  }

  /// Leave the queue
  Future<void> leaveQueue() async {
    if (_currentUserId == null) return;
    try {
      await _supabase.from('matchmaking_queue').delete().eq('user_id', _currentUserId!);
    } catch (e) {
      // Ignore error if already gone
    }
  }

  /// Check status of queue/self
  /// Returns {status: 'searching'|'matched', matchId: uuid, count: int}
  Future<Map<String, dynamic>> checkQueueStatus() async {
    if (_currentUserId == null) return {};
    
    try {
      // 1. Check my status
      final myEntry = await _supabase
          .from('matchmaking_queue')
          .select('status, match_id')
          .eq('user_id', _currentUserId!)
          .maybeSingle();
          
      if (myEntry == null) return {'status': 'none', 'count': 0};
      
      if (myEntry['status'] == 'matched') {
         return {
           'status': 'matched', 
           'matchId': myEntry['match_id'],
           'count': 4 // Full lobby
         };
      }
      
      // 2. Count "searching" players (including me)
      // Note: This is a loose count for UI visualization
      final countRes = await _supabase
          .from('matchmaking_queue')
          .count(CountOption.exact)
          .eq('status', 'searching');
          
      return {
        'status': 'searching',
        'matchId': null,
        'count': countRes
      };
      
    } catch (e) {
      debugPrint('Queue status check error: $e');
      return {'status': 'error', 'count': 0};
    }
  }

  /// Search for match (Client-side logic)
  /// Returns matchId if match is CREATED by me, null otherwise
  /// [minOpponents] - Minimum opponents required to create match (default 3 for 4-player game)
  Future<String?> tryCreateMatch({int minOpponents = 3}) async {
    if (_currentUserId == null) return null;

    try {
      // Get my points
      final profile = await _supabase
          .from('profiles')
          .select('ranked_points')
          .eq('id', _currentUserId!)
          .single();
      final myPoints = profile['ranked_points'] as int? ?? 0;

      // Always try to find up to 3 opponents to fill the lobby
      final result = await _supabase.rpc('find_ranked_opponents', params: {
        'p_user_id': _currentUserId,
        'p_points': myPoints,
        'p_limit': 3, 
      });

      final opponents = result as List;
      
      // Check if we meet the minimum requirement
      if (opponents.length >= minOpponents) {
        // Take as many as we found (up to 3)
        final opponentIds = opponents.take(3).map((o) => o['user_id'] as String).toList();
        final matchId = _uuid.v4().substring(0, 6).toUpperCase();
        
        // Atomic Create
        final success = await _supabase.rpc('create_ranked_match', params: {
          'p_matchmaker_id': _currentUserId,
          'p_opponent_ids': opponentIds,
          'p_match_id': matchId,
        });
        
        if (success == true) {
          debugPrint('✅ Created Match $matchId with 4 players');
          return matchId;
        } else {
             debugPrint('⚠️ Failed to create match (Race condition)');
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('Matchmaking scan error: $e');
      return null;
    }
  }

  /// Report game result to backend (updates ELO)
  Future<void> reportResult({required bool isWin, required int pointsChange}) async {
     if (_currentUserId == null) return;
     try {
       await _supabase.rpc('update_ranked_result', params: {
         'p_user_id': _currentUserId,
         'p_points_change': pointsChange,
         'p_is_win': isWin,
       });
       debugPrint('🏆 Ranked result reported: ${isWin ? "WIN" : "LOSS"} ($pointsChange pts)');
     } catch (e) {
       debugPrint('Error reporting ranked result: $e');
     }
  }

  /// Calculate ELO points change
  /// K-Factor = 32
  int calculateEloChange(int playerElo, int opponentElo, bool isWin) {
    const kFactor = 32;
    final expectedScore = 1 / (1 + pow(10, (opponentElo - playerElo) / 400));
    final actualScore = isWin ? 1.0 : 0.0;
    
    return (kFactor * (actualScore - expectedScore)).round();
  }
}
