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
  int _playersFound = 1; // Start with self

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

      setState(() => _statusMessage = "Waiting for players...");

      // 2. Poll status every 2 seconds
      _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
        final status = await _service.checkQueueStatus();
        
        if (!mounted) return;
        
        if (status['status'] == 'matched') {
           _handleMatchFound(status['matchId']);
           return;
        }
        
        // Update waiting count
        if (status['status'] == 'searching') {
          setState(() {
            _playersFound = (status['count'] as int? ?? 1).clamp(1, 4);
          });
          
          // Try to create match if we have enough players
          if (_playersFound >= 4) {
             final matchId = await _service.tryCreateMatch();
             if (matchId != null) {
               _handleMatchFound(matchId);
             }
          }
        }
      });
      
    } catch (e) {
      if (mounted) {
        setState(() => _statusMessage = "Error: $e");
      }
    }
  }

  Future<void> _handleMatchFound(String matchId) async {
    _pollTimer?.cancel();
    _foundMatch = true;
    
    setState(() {
      _statusMessage = "Match Starting!";
      _playersFound = 4; // Fill UI
    });
    
    // Slight delay for effect
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    try {
      // Join the game
      ref.read(gameStateProvider.notifier).joinGame(matchId);
      
      // Navigate to game
      Navigator.pop(context); 
      
    } catch (e) {
      setState(() => _statusMessage = "Failed to join: $e");
      _foundMatch = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Container(
          width: 340,
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
              Text(
                "RANKED LOBBY",
                style: GameTheme.h2.copyWith(fontSize: 20, color: GameTheme.accent),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // 4 Slots
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(4, (index) {
                  final isFilled = index < _playersFound;
                  return _buildPlayerSlot(isFilled);
                }),
              ),
              
              const SizedBox(height: 24),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: GameTheme.textSecondary, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
                child: const Text("Leave Queue"),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildPlayerSlot(bool isFilled) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: isFilled ? GameTheme.primary : Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFilled ? GameTheme.primary : Colors.grey.withOpacity(0.3),
           width: 2
        ),
      ),
      child: Center(
        child: isFilled 
          ? const Icon(Icons.person, color: Colors.white)
          : const CircularProgressIndicator(strokeWidth: 2, color: Colors.grey),
      ),
    );
  }
}
