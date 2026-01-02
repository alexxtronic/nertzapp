/// Friends Tab
/// 
/// Friend management and match creation:
/// - Create Match / Join Match buttons
/// - Add Friend functionality
/// - Friends list with challenge option

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../state/game_provider.dart';
import '../../services/supabase_service.dart';
import '../../services/friend_service.dart';
import '../theme/game_theme.dart';
import 'game_screen.dart';

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
  List<Friend> _friends = [];
  bool _isLoadingFriends = true;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    if (!mounted) return;
    setState(() => _isLoadingFriends = true);
    
    final friends = await FriendService().getFriends();
    
    if (mounted) {
      setState(() {
        _friends = friends;
        _isLoadingFriends = false;
      });
    }
  }

  @override
  @override
  void dispose() {
    _joinCodeController.dispose();
    _addFriendController.dispose(); // Added
    super.dispose();
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
              if (friend.isOnline)
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
                  friend.isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontSize: 12,
                    color: friend.isOnline ? Colors.green : GameTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // Create lobby and invite
              _createLobby();
              // In future: auto-send invite
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: GameTheme.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Challenge'),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GameTheme.glassBorder),
        boxShadow: GameTheme.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
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
      ),
    );
  }
}
