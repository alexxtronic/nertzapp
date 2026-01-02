/// Friend Service
/// 
/// Handles friend relationships:
/// - Send/accept/decline friend requests
/// - Get friends list
/// - Challenge friends to games

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Friend relationship status
enum FriendStatus { pending, accepted, blocked }

/// Friend model
class Friend {
  final String id;
  final String oderId; // the other person in the relationship
  final String odername;
  final String? avatarUrl;
  final FriendStatus status;
  final bool isOnline;
  final DateTime createdAt;

  const Friend({
    required this.id,
    required this.oderId,
    required this.odername,
    this.avatarUrl,
    required this.status,
    this.isOnline = false,
    required this.createdAt,
  });

  factory Friend.fromJson(Map<String, dynamic> json, String currentUserId) {
    // Determine if we sent or received the request
    final isSender = json['user_id'] == currentUserId;
    final otherProfile = isSender ? json['friend_profile'] : json['user_profile'];
    
    return Friend(
      id: json['id'] as String,
      oderId: isSender ? json['friend_id'] : json['user_id'],
      odername: otherProfile?['username'] ?? 'Unknown',
      avatarUrl: otherProfile?['avatar_url'],
      status: FriendStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => FriendStatus.pending,
      ),
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class FriendService {
  static final FriendService _instance = FriendService._internal();
  factory FriendService() => _instance;
  FriendService._internal();

  final _supabase = Supabase.instance.client;
  
  String? get _currentUserId => _supabase.auth.currentUser?.id;

  /// Get all friends (accepted)
  Future<List<Friend>> getFriends() async {
    if (_currentUserId == null) return [];
    
    try {
      // Get friendships where we are either sender or receiver
      final response = await _supabase
          .from('friends')
          .select('''
            id, user_id, friend_id, status, created_at,
            user_profile:profiles!friends_user_id_fkey(username, avatar_url),
            friend_profile:profiles!friends_friend_id_fkey(username, avatar_url)
          ''')
          .or('user_id.eq.${_currentUserId},friend_id.eq.${_currentUserId}')
          .eq('status', 'accepted');
      
      return (response as List)
          .map((json) => Friend.fromJson(json, _currentUserId!))
          .toList();
    } catch (e) {
      debugPrint('Error fetching friends: $e');
      return [];
    }
  }

  /// Get pending friend requests (received)
  Future<List<Friend>> getPendingRequests() async {
    if (_currentUserId == null) return [];
    
    try {
      final response = await _supabase
          .from('friends')
          .select('''
            id, user_id, friend_id, status, created_at,
            user_profile:profiles!friends_user_id_fkey(username, avatar_url),
            friend_profile:profiles!friends_friend_id_fkey(username, avatar_url)
          ''')
          .eq('friend_id', _currentUserId!)
          .eq('status', 'pending');
      
      return (response as List)
          .map((json) => Friend.fromJson(json, _currentUserId!))
          .toList();
    } catch (e) {
      debugPrint('Error fetching pending requests: $e');
      return [];
    }
  }

  /// Send friend request by username
  Future<bool> sendFriendRequest(String username) async {
    if (_currentUserId == null) return false;
    
    try {
      // Find user by username
      final userResult = await _supabase
          .from('profiles')
          .select('id')
          .eq('username', username)
          .maybeSingle();
      
      if (userResult == null) {
        throw Exception('User not found');
      }
      
      final friendId = userResult['id'] as String;
      
      // Can't friend yourself
      if (friendId == _currentUserId) {
        throw Exception('Cannot add yourself as a friend');
      }
      
      // Check if already friends or pending
      final existing = await _supabase
          .from('friends')
          .select('id')
          .or('and(user_id.eq.${_currentUserId},friend_id.eq.$friendId),and(user_id.eq.$friendId,friend_id.eq.${_currentUserId})')
          .maybeSingle();
      
      if (existing != null) {
        throw Exception('Friend request already exists');
      }
      
      // Create friend request
      await _supabase.from('friends').insert({
        'user_id': _currentUserId,
        'friend_id': friendId,
        'status': 'pending',
      });
      
      debugPrint('✅ Friend request sent to $username');
      return true;
    } catch (e) {
      debugPrint('Error sending friend request: $e');
      rethrow;
    }
  }

  /// Accept friend request
  Future<bool> acceptFriendRequest(String friendshipId) async {
    try {
      await _supabase
          .from('friends')
          .update({'status': 'accepted', 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', friendshipId);
      
      debugPrint('✅ Friend request accepted');
      return true;
    } catch (e) {
      debugPrint('Error accepting friend request: $e');
      return false;
    }
  }

  /// Decline/remove friend
  Future<bool> removeFriend(String friendshipId) async {
    try {
      await _supabase
          .from('friends')
          .delete()
          .eq('id', friendshipId);
      
      debugPrint('✅ Friend removed');
      return true;
    } catch (e) {
      debugPrint('Error removing friend: $e');
      return false;
    }
  }

  /// Stream friends list (for realtime updates)
  Stream<List<Friend>> streamFriends() {
    if (_currentUserId == null) return const Stream.empty();
    
    return _supabase
        .from('friends')
        .stream(primaryKey: ['id'])
        .map((data) {
          return data
              .where((json) => 
                  (json['user_id'] == _currentUserId || json['friend_id'] == _currentUserId) &&
                  json['status'] == 'accepted')
              .map((json) => Friend.fromJson(json, _currentUserId!))
              .toList();
        });
  }
}
