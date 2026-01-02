import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/matchmaking_service.dart';
import '../theme/game_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/game_provider.dart';

class QuickMatchOverlay extends ConsumerStatefulWidget {
  const QuickMatchOverlay({super.key});

  @override
  ConsumerState<QuickMatchOverlay> createState() => _QuickMatchOverlayState();
}

class _QuickMatchOverlayState extends ConsumerState<QuickMatchOverlay> {
  Timer? _pollTimer;
  String _statusMessage = "Joining queue...";
  final _service = MatchmakingService();
  bool _foundMatch = false;

  @override
  void initState() {
    super.initState();
    _startMatchmaking();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    if (!_foundMatch) {
      _service.leaveQueue();
    }
    super.dispose();
  }

  Future<void> _startMatchmaking() async {
    try {
      // 1. Join Queue
      await _service.joinQueue();
      if (!mounted) return;

      setState(() => _statusMessage = "Searching for opponents...");

      // 2. Poll for opponents every 3 seconds
      _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
        final opponents = await _service.scanForOpponents();
        
        if (!mounted) return;

        if (opponents.isNotEmpty) {
           _handleMatchFound(opponents);
        } else {
           // Update UI to show we are still waiting
           // In a real app we might show "Searching..." with animated dots
        }
      });
      
    } catch (e) {
      if (mounted) {
        setState(() => _statusMessage = "Error: $e");
      }
    }
  }

  Future<void> _handleMatchFound(List<String> opponents) async {
    _pollTimer?.cancel();
    _foundMatch = true;
    
    setState(() => _statusMessage = "Opponents found! Creating match...");

    try {
      final lobbyCode = await _service.createRankedMatch(opponents);
      
      if (!mounted) return;
      
      // Join the game
      ref.read(gameStateProvider.notifier).joinGame(lobbyCode);
      
      // Navigate to game (close overlay then push)
      Navigator.pop(context); // Close overlay
      // Navigation is usually handled by parent or router listener, 
      // but here we might need to trigger it manually if not listening to game state changes
      // The parent BattleTab listens to game state or we can just push directly
      
      // For now, let's trigger the nav via callback or provider if possible.
      // Assuming BattleTab handles navigation based on game state, or we can't easily push from here without context issues.
      // We'll update the game state and let the UI react.
      
    } catch (e) {
      setState(() => _statusMessage = "Failed to start match: $e");
      _foundMatch = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: GameTheme.surfaceLight,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: GameTheme.accent, width: 2),
            boxShadow: GameTheme.softShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: GameTheme.accent),
              const SizedBox(height: 24),
              Text(
                "RANKED MATCHMAKING",
                style: GameTheme.h2.copyWith(fontSize: 20, color: GameTheme.accent),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: GameTheme.textSecondary),
              ),
              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
                child: const Text("Cancel"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
