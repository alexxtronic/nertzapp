/// Friends Tab
/// 
/// Friend management and match creation:
/// - Create Match / Join Match buttons
/// - Add Friend functionality
/// - Friends list with challenge option

import 'dart:async';
import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../state/game_provider.dart';
import '../../services/supabase_service.dart';
import '../../services/friend_service.dart';
import '../theme/game_theme.dart';
import 'game_screen.dart';
import '../widgets/bounceable.dart';

class FriendsTab extends ConsumerStatefulWidget {
  const FriendsTab({super.key});

  @override
  ConsumerState<FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends ConsumerState<FriendsTab> {
  final _joinCodeController = TextEditingController();
  final _addFriendController = TextEditingController(); // Added
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  
  // Real friends data
  // Friends Data
  List<Friend> _friends = [];
  List<Friend> _pendingRequests = [];
  bool _isLoadingFriends = true;
  
  // Realtime subscription
  RealtimeChannel? _friendsSubscription;

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _subscribeToFriendUpdates();
    _setupPresenceListener(); // Added
  }

  void _subscribeToFriendUpdates() {
    _friendsSubscription = _supabase
        .channel('public:friends')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'friends',
          callback: (payload) {
            // Refresh on any change involving this user
            // We reload indiscriminately on any friends table change for simplicity 
            // (in prod, filter by user_id/friend_id)
            _loadFriends(); 
          },
        )
        .subscribe();
  }

  Future<void> _loadFriends() async {
    if (!mounted) return;
    setState(() => _isLoadingFriends = true);
    
    final friends = await FriendService().getFriends();
    final pending = await FriendService().getPendingRequests();
    
    if (mounted) {
      setState(() {
        _friends = friends;
        _pendingRequests = pending;
        _isLoadingFriends = false;
      });
    }
  }

  Future<void> _acceptRequest(String friendshipId) async {
    final success = await FriendService().acceptFriendRequest(friendshipId);
    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request accepted!'), backgroundColor: Colors.green),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to accept request. Please try again.'), backgroundColor: Colors.red),
        );
      }
    }
    _loadFriends(); // Refresh
  }

  Future<void> _denyRequest(String friendshipId) async {
    await FriendService().removeFriend(friendshipId);
    _loadFriends(); // Refresh
  }

  @override
  @override
  void dispose() {
    _joinCodeController.dispose();
    _addFriendController.dispose(); // Added
    _friendsSubscription?.unsubscribe();
    _presenceSubscription?.cancel(); // Added
    super.dispose();
  }

  // Presence Listener
  StreamSubscription? _presenceSubscription;
  
  void _setupPresenceListener() {
    _presenceSubscription = FriendService().onPresenceUpdate.listen((_) {
      if (mounted) setState(() {}); // Rebuild to show green dots
    });
  }

  Future<void> _inviteFriend(Friend friend) async {
    setState(() => _isLoading = true);
    
    try {
      // 1. Ensure we have a lobby
      final gameState = ref.read(gameStateProvider);
      String code;
      
      if (gameState != null && gameState.hostId == _supabase.auth.currentUser?.id) {
         // Already hosting
         code = gameState.matchId;
      } else {
         // Create new lobby
         final lobbyId = await SupabaseService().createLobby();
         if (lobbyId == null) throw Exception("Failed to create lobby");
         final lobby = await _supabase.from('lobbies').select('code').eq('id', lobbyId).single();
         code = lobby['code'];
         ref.read(gameStateProvider.notifier).hostGame(code); // Join as host
      }
      
      // 2. Send Invite
      final profile = await SupabaseService().getProfile();
      final myName = profile?['username'] ?? 'Friend';
      
      await FriendService().sendGameInvite(friend.oderId, code, myName);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invite sent to ${friend.odername}!'), backgroundColor: Colors.green),
        );
        _navigateToGame();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error inviting: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createLobby() async {
    setState(() => _isLoading = true);
    
    final lobbyId = await SupabaseService().createLobby();
    
    String? code;
    if (lobbyId != null) {
      final lobby = await _supabase.from('lobbies').select('code').eq('id', lobbyId).single();
      code = lobby['code'] as String?;
    }
    
    setState(() => _isLoading = false);
    
    if (code != null) {
      ref.read(gameStateProvider.notifier).hostGame(code);
      _navigateToGame();
    }
  }

  void _showJoinDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          decoration: GameTheme.glassDecoration,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Join Match 🎮", style: GameTheme.h2),
              const SizedBox(height: 24),
              TextField(
                controller: _joinCodeController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(
                  labelText: 'Enter Match Code',
                  labelStyle: TextStyle(color: GameTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54, width: 2)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: GameTheme.accent, width: 2)),
                ),
                style: const TextStyle(color: GameTheme.textPrimary, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 8),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    child: const Text("Cancel", style: TextStyle(color: GameTheme.textSecondary)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GameTheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text("Join"),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _joinMatch(_joinCodeController.text.trim());
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _joinMatch(String code) {
    if (code.isEmpty) return;
    ref.read(gameStateProvider.notifier).joinGame(code);
    _navigateToGame();
  }

  void _navigateToGame() {
    Navigator.of(context).push(
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
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          
          // Match buttons section
          const Text('PRIVATE MATCHES', style: GameTheme.label),
          const SizedBox(height: 16),
          
          // Create Match
          _buildActionCard(
            title: 'Create Match',
            subtitle: 'Host a private lobby with a code',
            icon: Icons.add_circle_outline,
            color: GameTheme.primary,
            onPressed: _isLoading ? null : _createLobby,
          ),
          const SizedBox(height: 12),
          
          // Join Match
          _buildActionCard(
            title: 'Join Match',
            subtitle: 'Enter a 6-digit code from a friend',
            icon: Icons.login,
            color: GameTheme.accent,
            onPressed: _isLoading ? null : _showJoinDialog,
          ),
          
          const SizedBox(height: 32),
          
          // PENDING REQUESTS SECTION
          if (_pendingRequests.isNotEmpty) ...[
            const Text('PENDING REQUESTS', style: GameTheme.label),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _pendingRequests.length,
              itemBuilder: (context, index) {
                return _buildPendingRequestItem(_pendingRequests[index]);
              },
            ),
            const SizedBox(height: 24),
          ],
          
          // Friends section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('FRIENDS', style: GameTheme.label),
              TextButton.icon(
                onPressed: _showAddFriendDialog, // Changed to real function
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Friends List
          _isLoadingFriends
              ? const Center(child: CircularProgressIndicator())
              : _friends.isEmpty
                  ? _buildEmptyFriendsState()
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _friends.length,
                      itemBuilder: (context, index) {
                        final friend = _friends[index];
                        return _buildFriendItem(friend);
                      },
                    ),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildEmptyFriendsState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GameTheme.glassBorder),
      ),
      child: Column(
        children: [
          Icon(
            Icons.group_outlined,
            size: 48,
            color: GameTheme.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'No friends yet',
            style: TextStyle(
              color: GameTheme.textSecondary.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add friends to challenge them!',
            style: TextStyle(
              color: GameTheme.textSecondary.withValues(alpha: 0.5),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildFriendItem(Friend friend) {
    final isOnline = FriendService().isUserOnline(friend.oderId) || friend.isOnline; // Check realtime + model fallback
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: GameTheme.softShadow,
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: friend.avatarUrl != null 
                    ? NetworkImage(friend.avatarUrl!) 
                    : const AssetImage('assets/default_avatar.jpg') as ImageProvider,
              ),
              if (isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.odername,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: GameTheme.textPrimary,
                  ),
                ),
                Text(
                  isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontSize: 12,
                    color: isOnline ? Colors.green : GameTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Bounceable(
            onTap: isOnline ? () => _inviteFriend(friend) : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isOnline ? GameTheme.accent : Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(4), // Match Default ElevatedButton shape or slightly rounded
                boxShadow: isOnline ? [
                  BoxShadow(
                    color: GameTheme.accent.withOpacity(0.4),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ] : null,
              ),
              child: const Text(
                'Invite',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddFriendDialog() {
    _addFriendController.clear();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(24),
          decoration: GameTheme.glassDecoration,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Add Friend 👋", style: GameTheme.h2),
              const SizedBox(height: 16),
              const Text(
                "Enter their username to send a request",
                textAlign: TextAlign.center,
                style: TextStyle(color: GameTheme.textSecondary),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _addFriendController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixIcon: Icon(Icons.person_search),
                  filled: true,
                  fillColor: Colors.white54,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    child: const Text("Cancel"),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final username = _addFriendController.text.trim();
                      if (username.isEmpty) return;
                      
                      Navigator.pop(ctx);
                      
                      try {
                        await FriendService().sendFriendRequest(username);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Friend request sent!'), backgroundColor: Colors.green),
                          );
                        }
                      } catch (e) {
                         if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GameTheme.primary,
                    ),
                    child: const Text("Send"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onPressed,
  }) {
    return Bounceable(
      onTap: onPressed,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: GameTheme.glassBorder),
          boxShadow: GameTheme.softShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: GameTheme.textPrimary,
                      ),
                    ),
                    Text(subtitle, style: GameTheme.bodyMedium),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: GameTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildPendingRequestItem(Friend request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.5)),
        boxShadow: GameTheme.softShadow,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: request.avatarUrl != null 
                ? NetworkImage(request.avatarUrl!) 
                : const AssetImage('assets/default_avatar.jpg') as ImageProvider,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              request.odername,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: GameTheme.textPrimary,
                fontSize: 16,
              ),
            ),
          ),
          // Accept Button
          IconButton(
            onPressed: () => _acceptRequest(request.id),
            icon: const Icon(Icons.check_circle, color: Colors.green, size: 32),
            tooltip: 'Accept',
          ),
          // Deny Button
          IconButton(
            onPressed: () => _denyRequest(request.id),
            icon: const Icon(Icons.cancel, color: Colors.red, size: 32),
            tooltip: 'Deny',
          ),
        ],
      ),
    );
  }
}
