import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/game_provider.dart';
import '../../models/player_state.dart';
import '../theme/game_theme.dart';
import '../../services/supabase_service.dart'; // Added this import for SupabaseService

class LobbyOverlay extends ConsumerStatefulWidget {
  final String matchId;
  final bool isHost;
  final VoidCallback? onClose;
  
  const LobbyOverlay({
    super.key,
    required this.matchId,
    required this.isHost,
    this.onClose,
  });

  @override
  ConsumerState<LobbyOverlay> createState() => _LobbyOverlayState();
}

class _LobbyOverlayState extends ConsumerState<LobbyOverlay> {
  final TextEditingController _inviteController = TextEditingController();

  @override
  void dispose() {
    _inviteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameStateProvider);
    if (gameState == null) return const SizedBox.shrink();

    final players = gameState.players.values.toList();
    
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Container(
              width: 400,
              padding: const EdgeInsets.all(32),
              decoration: GameTheme.glassDecoration,
              child: Stack(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'LOBBY',
                        style: GameTheme.h1,
                      ),
                  const SizedBox(height: 24),
                  
                  // Match Code
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9), // Solid Slate 100
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: GameTheme.glassBorder),
                    ),
                    child: Column(
                      children: [
                        const Text('MATCH CODE', style: GameTheme.label),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SelectableText(
                              widget.matchId,
                              style: GameTheme.h1.copyWith(
                                color: Colors.black,
                                letterSpacing: 8,
                              ),
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              icon: const Icon(Icons.copy, color: GameTheme.primary), // Changed to primary for visibility on light bg
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: widget.matchId));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Code copied!')),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Invite Player Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9), // Solid Slate 100
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: GameTheme.glassBorder),
                    ),
                    child: Column(
                      children: [
                        const Text('INVITE FRIEND', style: GameTheme.label),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _inviteController,
                                style: const TextStyle(color: GameTheme.textPrimary),
                                decoration: const InputDecoration(
                                  hintText: 'Enter Username',
                                  hintStyle: TextStyle(color: GameTheme.textSecondary),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: GameTheme.glassBorder)),
                                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: GameTheme.accent)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () async {
                                final username = _inviteController.text.trim();
                                if (username.isEmpty) return;
                                
                                try {
                                  await SupabaseService().sendInvite(username, widget.matchId);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Invitation sent!')),
                                    );
                                    _inviteController.clear();
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Failed: ${e.toString().replaceAll("Exception: ", "")}')),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.send, color: GameTheme.accent),
                              tooltip: 'Send Invite',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Player List
                  const Text('PLAYERS', style: GameTheme.label),
                  const SizedBox(height: 16),
                  ...players.map((p) => _buildPlayerTile(p)).toList(),
                  
                  if (players.length < 2)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Waiting for others to join...',
                        style: GameTheme.body.copyWith(fontStyle: FontStyle.italic),
                      ),
                    ),
                    
                  const SizedBox(height: 32),
                  
                  // Action Button
                  if (widget.isHost)
                    ElevatedButton(
                      onPressed: players.length >= 2 
                        ? () => ref.read(gameStateProvider.notifier).startNewRound()
                        : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GameTheme.success,
                        disabledBackgroundColor: Colors.grey,
                        minimumSize: const Size(double.infinity, 56),
                      ),
                      child: const Text('START GAME', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    )
                  else
                    const Text(
                      'Waiting for host to start...',
                      style: GameTheme.h2,
                    ),
                ],
              ),
              Positioned(
                right: 0,
                top: 0,
                child: IconButton(
                  icon: const Icon(Icons.close, color: GameTheme.textPrimary),
                  onPressed: widget.onClose,
                ),
              ),
            ],
          ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerTile(PlayerState player) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9), // Solid Slate 100
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: GameTheme.glassBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: GameTheme.primary,
            backgroundImage: player.avatarUrl != null 
              ? NetworkImage(player.avatarUrl!) 
              : const AssetImage('assets/default_avatar.jpg') as ImageProvider,
            child: null,
          ),
          const SizedBox(width: 12),
          Text(player.displayName, style: GameTheme.body),
          const Spacer(),
          // Rank Badge small
          if (player.wins > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: GameTheme.primary, // Solid primary for badge
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                player.rank.name.toUpperCase(),
                style: const TextStyle(fontSize: 10, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
