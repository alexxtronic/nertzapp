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

  /// Search for match (Client-side logic for now)
  /// Returns List of opponent User IDs if match found, empty if still searching
  Future<List<String>> scanForOpponents() async {
    if (_currentUserId == null) return [];

    try {
      // Get my points
      final profile = await _supabase
          .from('profiles')
          .select('ranked_points')
          .eq('id', _currentUserId!)
          .single();
      final myPoints = profile['ranked_points'] as int? ?? 1000;

      // Find 1-3 opponents
      final result = await _supabase.rpc('find_ranked_opponents', params: {
        'p_user_id': _currentUserId,
        'p_points': myPoints,
        'p_limit': 3, // Try to find full game
      });

      final opponents = result as List;
      
      // If we found at least 1 opponent, we can start a match
      // (For now, even 1v1 is fine to start quickly)
      if (opponents.isNotEmpty) {
        final opponentIds = opponents.map((o) => o['user_id'] as String).toList();
        
        // Remove everyone from queue (atomic-ish)
        // In real server, this would be a transaction. 
        // Here we just try our best to claim them.
        
        await _supabase.from('matchmaking_queue')
            .update({'status': 'matched'})
            .filter('user_id', 'in', opponentIds);
            
        return opponentIds;
      }
      
      return [];
    } catch (e) {
      debugPrint('Matchmaking scan error: $e');
      return [];
    }
  }

  /// Create a ranked lobby with found opponents
  Future<String> createRankedMatch(List<String> opponentIds) async {
    // create lobby
    // invite/add players directly
    // return lobby code
    
    // NOTE: This reuses SupabaseService.createLobby logic but marks it ranked
    // For MVP, we use the regular lobby but track it as ranked in our heads/local state
    // Ideally, Lobby table should have 'is_ranked' column.
    
    // For now we just return a new match ID and let the clients join via code/invite
    // Since we don't have server-side forcing, we assume invited players join.
    
    // This part bridges to the existing GameStateNotifier logic
    return _uuid.v4().substring(0, 6).toUpperCase(); 
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
