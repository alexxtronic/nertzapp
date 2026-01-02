/// Battle Tab - Home Screen
/// 
/// Main game modes screen with:
/// - Splash hero image
/// - Ranked Quick Match (orange-red)
/// - Play Offline (blue)
/// - Battle a Friend (links to Friends tab)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/game_provider.dart';
import '../../services/audio_service.dart';
import '../../state/economy_provider.dart';
import '../theme/game_theme.dart';
import '../widgets/bot_difficulty_dialog.dart';
import '../widgets/quick_match_overlay.dart'; // Added
import 'game_screen.dart';
import 'main_navigation_screen.dart';

class BattleTab extends ConsumerStatefulWidget {
  const BattleTab({super.key});

  @override
  ConsumerState<BattleTab> createState() => _BattleTabState();
}

class _BattleTabState extends ConsumerState<BattleTab> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Start background music
    ref.read(selectedMusicAssetProvider.future).then((path) {
      if (mounted) {
        AudioService().startBackgroundMusic(path: path);
      }
    });
  }

  void _startLocalGame() {
    ref.read(gameStateProvider.notifier).createLocalGame();
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

  Future<void> _handleRankedMatch() async {
    // Show matchmaking overlay
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const QuickMatchOverlay(),
    );
    
    // Check if we joined a game (via provider change)
    final matchId = ref.read(matchIdProvider);
    if (matchId != null) {
      if (mounted) _navigateToGame();
    }
  }

  void _goToFriendsTab() {
    // Switch to Friends tab (index 3)
    ref.read(currentTabProvider.notifier).state = 3;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero Image
          Container(
            margin: const EdgeInsets.only(bottom: 32),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/splash_hero.png',
                height: 200,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  height: 200,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [GameTheme.primary, GameTheme.secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Center(
                    child: Text(
                      'NERTZ ROYALE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Ranked Quick Match Button
          _buildGameButton(
            title: 'Ranked Quick Match!',
            subtitle: '3 rounds • 4 players • ELO ranked',
            icon: Icons.bolt,
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6B35), Color(0xFFE53935)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            onPressed: _isLoading ? null : _handleRankedMatch,
            badge: 'RANKED',
          ),
          const SizedBox(height: 16),

          // Play Offline Button
          _buildGameButton(
            title: 'Play Offline',
            subtitle: 'Battle AI bots',
            icon: Icons.smart_toy_outlined,
            gradient: const LinearGradient(
              colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            onPressed: _isLoading ? null : _startLocalGame,
            trailing: GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => const BotDifficultyDialog(),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.settings, color: Colors.white, size: 20),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Battle a Friend Button
          _buildGameButton(
            title: 'Battle a Friend!',
            subtitle: 'Create or join a private match',
            icon: Icons.group,
            gradient: const LinearGradient(
              colors: [Color(0xFF4CAF50), Color(0xFF388E3C)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            onPressed: _goToFriendsTab,
          ),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildGameButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Gradient gradient,
    VoidCallback? onPressed,
    String? badge,
    Widget? trailing,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (gradient as LinearGradient).colors.first.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
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
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                badge,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing,
                if (trailing == null)
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white.withOpacity(0.7),
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
