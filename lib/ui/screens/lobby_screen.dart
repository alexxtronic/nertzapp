import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Added this
import 'package:nertz_royale/services/supabase_service.dart';
import 'package:nertz_royale/ui/screens/profile_screen.dart';

import '../../state/game_provider.dart';
import '../theme/game_theme.dart';
import '../widgets/invitations_dialog.dart';
import 'game_screen.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  final _joinCodeController = TextEditingController();
  final SupabaseService _authService = SupabaseService();
  final _supabase = Supabase.instance.client; // Added this
  
  bool _isLoading = false;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _initAuth();
  }
  
  Future<void> _initAuth() async {
    try {
      if (_authService.currentUser == null) {
        await _authService.signInAnonymously();
      }
      _refreshProfile();
    } catch (e) {
      debugPrint('Auth init failed: $e');
    }
  }

  Future<void> _refreshProfile() async {
    final p = await _authService.getProfile();
    if (mounted) setState(() => _profile = p);
  }

  @override
  void dispose() {
    _joinCodeController.dispose();
    super.dispose();
  }

  void _startLocalGame() {
    ref.read(gameStateProvider.notifier).createLocalGame();
    _navigateToGame();
  }
  
  Future<void> _createLobby() async {
    setState(() => _isLoading = true);
    
    // 1. Create entry in 'lobbies' table to get a code
    final lobbyId = await _authService.createLobby();
    
    // 2. Fetch the code we just created
    String? code;
    if (lobbyId != null) {
      final lobby = await _supabase.from('lobbies').select('code').eq('id', lobbyId).single();
      code = lobby['code'] as String?;
    }
    
    setState(() => _isLoading = false);
    
    if (code != null) {
      // 3. Initialize GameState with THIS code
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
    
    // Join P2P
    ref.read(gameStateProvider.notifier).joinGame(code);
    _navigateToGame();
  }

  void _navigateToGame() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GameScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = _profile?['avatar_url'] as String?;
    final username = _profile?['username'] ?? 'Player';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: GameTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Profile & Invites Button (Top Right)
              Positioned(
                top: 16,
                right: 16,
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: SupabaseService().getInvitesStream(),
                  builder: (context, snapshot) {
                      final inviteCount = snapshot.data?.length ?? 0;
                      
                      return GestureDetector(
                        onTap: () async {
                           if (inviteCount > 0) {
                              // Prioritize showing invites if any
                              await showDialog(
                                context: context,
                                builder: (_) => const InvitationsDialog(),
                              );
                           } else {
                              // Otherwise show profile
                              await Navigator.push(
                                context, 
                                MaterialPageRoute(builder: (_) => const ProfileScreen())
                              );
                           }
                           _refreshProfile();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: GameTheme.glassDecoration.copyWith(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Row(
                            children: [
                              Text(
                                username,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                   CircleAvatar(
                                     radius: 16,
                                     backgroundColor: GameTheme.primary,
                                     backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                                     child: avatarUrl == null 
                                       ? const Icon(Icons.person, size: 20, color: Colors.white) 
                                       : null,
                                   ),
                                   if (inviteCount > 0)
                                     Positioned(
                                       top: -4,
                                       right: -4,
                                       child: Container(
                                         padding: const EdgeInsets.all(4),
                                         decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                         ),
                                         child: Text(
                                            inviteCount.toString(),
                                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
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
                ),
              ),
              
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: GameTheme.softShadow,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset(
                            'assets/app_icon.jpg',
                            fit: BoxFit.cover,
                            errorBuilder: (_,__,___) => Container(color: GameTheme.primary, child: const Icon(Icons.style, size: 64, color: Colors.white)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Title
                      const Text(
                        'NERTZ ROYALE',
                        style: TextStyle(
                          fontFamily: 'Roboto', // Or usage of GameTheme typography if defined
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          color: GameTheme.primary,
                          letterSpacing: 2,
                          shadows: [Shadow(color: Colors.black26, offset: Offset(0, 4), blurRadius: 10)],
                        ),
                      ),
                      const SizedBox(height: 48),

                      // Actions
                      _buildMenuButton(
                        icon: Icons.person,
                        label: 'PLAY OFFLINE',
                        color: GameTheme.secondary,
                        onPressed: _isLoading ? null : _startLocalGame,
                      ),
                      const SizedBox(height: 16),
                      _buildMenuButton(
                        icon: Icons.add_circle,
                        label: 'CREATE MATCH',
                        color: GameTheme.primary,
                        onPressed: _isLoading ? null : _createLobby,
                      ),
                      const SizedBox(height: 16),
                      _buildMenuButton(
                        icon: Icons.login,
                        label: 'JOIN MATCH',
                        color: GameTheme.accent,
                        onPressed: _isLoading ? null : _showJoinDialog,
                      ),
                      const SizedBox(height: 16),
                      
                      // Invite Friend placeholder - in a real app this would share the current Lobby Code
                      _buildMenuButton(
                        icon: Icons.share,
                        label: 'INVITE FRIEND',
                        color: Colors.white24,
                        onPressed: () {
                           ScaffoldMessenger.of(context).showSnackBar(
                             const SnackBar(content: Text('Host a match to get a code to share!')),
                           );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton({
    required IconData icon, 
    required String label, 
    required Color color, 
    VoidCallback? onPressed
  }) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 8,
          shadowColor: color.withValues(alpha: 0.4),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
