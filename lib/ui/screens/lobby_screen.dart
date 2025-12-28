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
    // AuthGate handles login now. Just refresh profile data.
    try {
      _refreshProfile();
    } catch (e) {
      debugPrint('Profile load failed: $e');
    }
  }

  Future<void> _refreshProfile() async {
    final p = await _authService.getProfile();
    if (mounted) {
      setState(() => _profile = p);
      // Update the player name provider with the actual profile username
      if (p != null && p['username'] != null) {
        ref.read(playerNameProvider.notifier).state = p['username'] as String;
      }
    }
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
    final wins = _profile?['wins'] ?? 0;

    return Scaffold(
      backgroundColor: GameTheme.surfaceLight, // Solid light grey background
      body: SafeArea(
        child: Column(
          children: [
            // 1. Header (Profile & Invites)
            _buildHeader(username, avatarUrl),
            
            // 2. Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Hero Section (Welcome)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: GameTheme.glassBorder),
                        boxShadow: GameTheme.softShadow,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Ready to play?', style: GameTheme.label),
                                const SizedBox(height: 8),
                                Text('Rank: Bronze', style: GameTheme.h2), // Placeholder for rank logic
                                const SizedBox(height: 4),
                                Text('$wins wins so far', style: GameTheme.bodyMedium),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: GameTheme.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.emoji_events, color: GameTheme.primary, size: 32),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    Text("GAME MODES", style: GameTheme.label),
                    const SizedBox(height: 16),
                    
                    // Game Mode Cards
                    _buildGameModeCard(
                      title: 'Play Offline',
                      subtitle: 'Practice vs Bots',
                      icon: Icons.person,
                      color: GameTheme.secondary,
                      onPressed: _isLoading ? null : _startLocalGame,
                    ),
                    const SizedBox(height: 16),
                    _buildGameModeCard(
                      title: 'Create Match',
                      subtitle: 'Host a private lobby',
                      icon: Icons.add_circle,
                      color: GameTheme.primary,
                      onPressed: _isLoading ? null : _createLobby,
                    ),
                    const SizedBox(height: 16),
                    _buildGameModeCard(
                      title: 'Join Match',
                      subtitle: 'Enter a 6-digit code',
                      icon: Icons.login,
                      color: GameTheme.accent,
                      onPressed: _isLoading ? null : _showJoinDialog,
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Sign Out (optional, but good for testing)
                    Center(
                      child: TextButton(
                        onPressed: () async {
                           await Supabase.instance.client.auth.signOut();
                           // AuthGate triggers rebuild -> LoginScreen
                        },
                        child: const Text('Sign Out', style: TextStyle(color: GameTheme.error)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String username, String? avatarUrl) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
               Hero(
                 tag: 'app_logo',
                 child: ClipRRect(
                   borderRadius: BorderRadius.circular(12),
                   child: Image.asset('assets/app_icon.jpg', width: 40, height: 40, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.style, color: GameTheme.primary)),
                 ),
               ),
               const SizedBox(width: 12),
               const Text("NERTZ ROYALE", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: GameTheme.textPrimary)),
            ],
          ),
          
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: SupabaseService().getInvitesStream(),
            builder: (context, snapshot) {
              final inviteCount = snapshot.data?.length ?? 0;
              return GestureDetector(
                onTap: () {
                   if (inviteCount > 0) {
                     showDialog(context: context, builder: (_) => const InvitationsDialog());
                   } else {
                     Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())).then((_) => _refreshProfile());
                   }
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                     CircleAvatar(
                       radius: 20,
                       backgroundColor: GameTheme.primary,
                       backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                       child: avatarUrl == null ? const Icon(Icons.person, color: Colors.white) : null,
                     ),
                     if (inviteCount > 0)
                       Positioned(
                         top: 0,
                         right: 0,
                         child: Container(
                           padding: const EdgeInsets.all(4),
                           decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2))),
                           child: Text('$inviteCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                         ),
                       ),
                  ],
                ),
              );
            }
          ),
        ],
      ),
    );
  }

  Widget _buildGameModeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: GameTheme.glassBorder),
        boxShadow: GameTheme.softShadow,
      ),
      child: Material( // For ripple
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: GameTheme.textPrimary)),
                      Text(subtitle, style: GameTheme.bodyMedium),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: GameTheme.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
