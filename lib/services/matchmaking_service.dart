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
      // Get current profile for points AND card back
      final profile = await _supabase
          .from('profiles')
          .select('username, avatar_url, ranked_points, selected_card_back')
          .eq('id', _currentUserId!)
          .single();

      final points = profile['ranked_points'] as int? ?? 1000;
      final username = profile['username'] as String? ?? 'Player';
      final avatarUrl = profile['avatar_url'] as String?;
      final selectedCardBack = profile['selected_card_back'] as String?;

      // Clean up any old entry
      await leaveQueue();

      // Insert into queue (includes card back for opponent display)
      await _supabase.from('matchmaking_queue').insert({
        'user_id': _currentUserId,
        'username': username,
        'avatar_url': avatarUrl,
        'ranked_points': points,
        'selected_card_back': selectedCardBack,
        'status': 'searching',
      });
      
      debugPrint('🔍 Joined matchmaking queue ($points ELO, card: $selectedCardBack)');
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
      debugPrint('👋 Left matchmaking queue');
    } catch (e) {
      // Ignore error if already gone
    }
  }

  /// Send heartbeat to keep our queue entry alive
  Future<void> sendHeartbeat() async {
    if (_currentUserId == null) return;
    try {
      await _supabase
          .from('matchmaking_queue')
          .update({'updated_at': DateTime.now().toUtc().toIso8601String()})
          .eq('user_id', _currentUserId!)
          .eq('status', 'searching');
    } catch (e) {
      // Ignore heartbeat failures
    }
  }

  /// Clean up stale queue entries (older than 2 minutes)
  /// Called occasionally, not on every poll
  static DateTime? _lastCleanup;
  
  Future<void> _cleanupStaleEntries() async {
    // Only run cleanup every 30 seconds max
    final now = DateTime.now();
    if (_lastCleanup != null && now.difference(_lastCleanup!).inSeconds < 30) {
      return; // Skip, ran recently
    }
    _lastCleanup = now;
    
    try {
      // 2 minute timeout - very generous
      final cutoff = now.toUtc().subtract(const Duration(minutes: 2)).toIso8601String();
      await _supabase
          .from('matchmaking_queue')
          .delete()
          .eq('status', 'searching')
          .lt('updated_at', cutoff);
      debugPrint('🧹 Cleaned up stale queue entries');
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  /// Check status of queue/self
  /// Returns {status: 'searching'|'matched', matchId: uuid, avatars: List<String?>}
  Future<Map<String, dynamic>> checkQueueStatus() async {
    if (_currentUserId == null) return {};
    
    // Clean stale entries occasionally (throttled internally)
    await _cleanupStaleEntries();
    
    try {
      // 1. Check my status
      final myEntry = await _supabase
          .from('matchmaking_queue')
          .select('status, match_id')
          .eq('user_id', _currentUserId!)
          .maybeSingle();
          
      if (myEntry == null) return {'status': 'none', 'avatars': <String?>[]};
      
      if (myEntry['status'] == 'matched') {
         return {
           'status': 'matched', 
           'matchId': myEntry['match_id'],
           'avatars': <String?>[], 
           'votes': 0, // Not needed
         };
      }
      
      // 2. Get searching players (up to 4)
      final searchingEntries = await _supabase
          .from('matchmaking_queue')
          .select('avatar_url, wants_to_start')
          .eq('status', 'searching')
          .order('created_at', ascending: true)
          .limit(4);
      
      final avatars = (searchingEntries as List).map((e) => e['avatar_url'] as String?).toList();
      final hasVoted = (searchingEntries).map((e) => e['wants_to_start'] as bool? ?? false).toList();
      final votes = hasVoted.where((v) => v).length;
      final total = searchingEntries.length;

      return {
        'status': 'searching',
        'matchId': null,
        'avatars': avatars,
        'hasVoted': hasVoted,
        'votes': votes,
        'total': total,
      };
      
    } catch (e) {
      debugPrint('Queue status check error: $e');
      return {'status': 'error', 'avatars': <String?>[], 'votes': 0, 'total': 0};
    }
  }

  /// Check if I am the host of this match (First player by created_at)
  /// [Deprecated] - We now use the "Active Starter" rule (RPC return value)
  
  /// Vote to Start
  /// Just records the vote. Does NOT trigger match creation.
  /// The countdown logic in the UI will later call tryCreateMatch.
  Future<void> voteToStart() async {
    if (_currentUserId == null) return;
    try {
      await _supabase.rpc('vote_to_start', params: {'p_user_id': _currentUserId!});
      debugPrint('🗳️ Vote recorded!');
    } catch (e) {
      debugPrint('Error voting to start: $e');
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
      
      if (opponents.length >= minOpponents) {
        // Take as many as we found (up to 3)
        final opponentIds = opponents.take(3).map((o) => o['user_id'] as String).toList();
        final matchId = _uuid.v4().substring(0, 6).toUpperCase();
        
        debugPrint('🎮 tryCreateMatch: Found ${opponents.length} opponents, creating match $matchId');
        debugPrint('🎮 Opponent IDs: $opponentIds');
        
        // Atomic Create
        final success = await _supabase.rpc('create_ranked_match', params: {
          'p_matchmaker_id': _currentUserId,
          'p_opponent_ids': opponentIds,
          'p_match_id': matchId,
        });
        
        debugPrint('🎮 create_ranked_match returned: $success');
        
        if (success == true) {
          debugPrint('✅ Created Match $matchId with ${opponentIds.length + 1} players');
          return matchId;
        } else {
          debugPrint('⚠️ create_ranked_match returned false (Race condition or players left)');
        }
      } else {
        debugPrint('⚠️ Not enough opponents: found ${opponents.length}, need $minOpponents');
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ Matchmaking scan error: $e');
      return null;
    }
  }

  /// Report ranked match result based on placement
  /// 1st place: total points + 50 bonus
  /// 2nd place: total points + 25 bonus
  /// 3rd/4th place: total points only (no bonus)
  Future<void> reportRankedMatchResult({
    required int placement, // 1, 2, 3, or 4
    required int totalPoints, // Score from the game
    int? bonusOverride, // Optional override (e.g. 25 for default win)
  }) async {
    if (_currentUserId == null) return;
    
    // Calculate bonus based on placement
    int bonus = 0;
    
    if (bonusOverride != null) {
      bonus = bonusOverride;
    } else {
      if (placement == 1) {
        bonus = 50;
      } else if (placement == 2) {
        bonus = 25;
      }
    }
    // 3rd and 4th get no bonus
    
    final pointsChange = totalPoints + bonus;
    final isWin = placement == 1; // Only 1st place counts as "win" for stats
    
    try {
      await _supabase.rpc('update_ranked_result', params: {
        'p_user_id': _currentUserId,
        'p_points_change': pointsChange,
        'p_is_win': isWin,
      });
      debugPrint('🏆 Ranked result: ${placement}${_getOrdinal(placement)} place, +$pointsChange points (base: $totalPoints, bonus: $bonus)');
    } catch (e) {
      debugPrint('Error reporting ranked result: $e');
    }
  }

  /// Deduct points for leaving a ranked game early
  Future<void> reportRankedPenalty(int penaltyPoints) async {
    if (_currentUserId == null) return;
    
    try {
      // Use negative change
      await _supabase.rpc('update_ranked_result', params: {
        'p_user_id': _currentUserId,
        'p_points_change': -penaltyPoints, // e.g. -20
        'p_is_win': false,
      });
      debugPrint('📉 Ranked penalty applied: -$penaltyPoints points');
    } catch (e) {
       debugPrint('Error reporting ranked penalty: $e');
    }
  }
  
  String _getOrdinal(int n) {
    if (n == 1) return 'st';
    if (n == 2) return 'nd';
    if (n == 3) return 'rd';
    return 'th';
  }
}
