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
import '../theme/game_theme.dart';
import 'game_screen.dart';

class FriendsTab extends ConsumerStatefulWidget {
  const FriendsTab({super.key});

  @override
  ConsumerState<FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends ConsumerState<FriendsTab> {
  final _joinCodeController = TextEditingController();
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;

  @override
  void dispose() {
    _joinCodeController.dispose();
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
                onPressed: () {
                  // TODO: Implement add friend
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Add Friend coming soon! 👋'),
                      backgroundColor: GameTheme.primary,
                    ),
                  );
                },
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Friends list placeholder
          Container(
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
                  color: GameTheme.textSecondary.withOpacity(0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  'No friends yet',
                  style: TextStyle(
                    color: GameTheme.textSecondary.withOpacity(0.7),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add friends to challenge them!',
                  style: TextStyle(
                    color: GameTheme.textSecondary.withOpacity(0.5),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
        ],
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
