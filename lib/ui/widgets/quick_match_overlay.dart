import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../theme/game_theme.dart';

/// Quick Match Overlay - Work in Progress
/// 
/// This feature is currently under development. When complete, it will:
/// 1. Add user to a matchmaking queue
/// 2. Wait for enough players
/// 3. Create a match and navigate to the game
/// 
/// For now, this shows a placeholder UI.
class QuickMatchOverlay extends StatefulWidget {
  const QuickMatchOverlay({super.key});

  @override
  State<QuickMatchOverlay> createState() => _QuickMatchOverlayState();
}

class _QuickMatchOverlayState extends State<QuickMatchOverlay> {
  StreamSubscription? _queueSub;
  String? _joinedLobbyId;
  String _statusMessage = "Joining queue...";
  final String _currentUserId = SupabaseService().currentUser?.id ?? '';
  bool _isCreator = false;

  @override
  void initState() {
    super.initState();
    _startMatchmaking();
  }

  @override
  void dispose() {
    _queueSub?.cancel();
    if (_joinedLobbyId == null) {
      SupabaseService().leaveQueue(); // Leave if closed without joining game
    }
    super.dispose();
  }

  Future<void> _startMatchmaking() async {
    // 1. Join Queue
    await SupabaseService().joinQueue();
    if (!mounted) return;

    setState(() => _statusMessage = "Searching for players...");

    // 2. Listen to queue
    _queueSub = SupabaseService().getQueueStream().listen((queue) {
      if (!mounted) return;

      final myEntry = queue.firstWhere(
        (e) => e['user_id'] == _currentUserId, 
        orElse: () => {}, 
      );
      
      // If we disappear from queue, maybe matched? Or removed?
      if (myEntry.isEmpty) {
        return;
      }
      
      // Check if we are matched
      if (myEntry['match_id'] != null) {
        _handleMatchFound(myEntry['match_id'] as String);
        return;
      }

      final waitingPlayers = queue.where((p) => p['match_id'] == null).toList();
      
      // Only the "leader" (longest waiter) triggers the match
      if (waitingPlayers.length >= 2) { // Allow 2 players for testing (normally 4)
         final leader = waitingPlayers.first;
         if (leader['user_id'] == _currentUserId && !_isCreator) {
            _isCreator = true; // Prevent duplicate create calls
            _createMatch(waitingPlayers.take(4).toList());
         }
      }
      
      setState(() {
        _statusMessage = "Searching for players... (${waitingPlayers.length}/4)";
      });
    });
  }

  Future<void> _createMatch(List<Map<String, dynamic>> players) async {
    setState(() => _statusMessage = "Creating match...");
    
    // 1. Create Lobby
    final lobbyCode = await SupabaseService().createLobby();
    if (lobbyCode == null) return;
    
    // TODO: A robust implementation would have createLobby return the full lobby object
    // including the UUID, so we can update the queue entries with match_id
  }
  
  void _handleMatchFound(String matchId) {
    _joinedLobbyId = matchId;
    _queueSub?.cancel();
    
    // TODO: Navigate to game screen with match ID
    // Navigator.of(context).pushReplacement(
    //   MaterialPageRoute(builder: (_) => GameScreen(matchId: matchId)),
    // );
    
    setState(() => _statusMessage = "Match found! Loading...");
    
    // For now, just close and let user join via lobby
    Navigator.of(context).pop();
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: GameTheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: GameTheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                _statusMessage,
                style: const TextStyle(
                  color: GameTheme.textPrimary,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () {
                  _queueSub?.cancel();
                  SupabaseService().leaveQueue();
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'CANCEL',
                  style: TextStyle(color: GameTheme.error),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
