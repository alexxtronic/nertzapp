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
  Timer? _countdownTimer;
  String _statusMessage = "Joining queue...";
  final _service = MatchmakingService();
  bool _foundMatch = false;
  List<String?> _foundAvatars = [];
  List<bool> _playersVoted = [];
  int _countdown = 10;
  bool _isCountdownActive = false;
  bool _iHaveVoted = false;

  @override
  void initState() {
    super.initState();
    _startMatchmaking();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _cancelCountdown();
    if (!_foundMatch) {
      _service.leaveQueue();
    }
    super.dispose();
  }

  void _startCountdown() {
    if (_isCountdownActive) return;
    
    setState(() {
      _isCountdownActive = true;
      _countdown = 10;
      _statusMessage = "Starting in $_countdown...";
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _countdown--;
        _statusMessage = "Starting in $_countdown...";
      });

      if (_countdown <= 0) {
        _cancelCountdown();
        _finalizeMatchStart();
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    if (mounted && _isCountdownActive) {
      setState(() {
        _isCountdownActive = false;
        _countdown = 10;
        _statusMessage = "Waiting for players...";
      });
    }
  }

  Future<void> _finalizeMatchStart() async {
     setState(() => _statusMessage = "Launching...");
     // Trigger the match creation.
     // Thanks to our DB locking, if everyone calls this at 0s, only one will succeed and become Host.
     final matchId = await _service.tryCreateMatch();
     if (matchId != null) {
       _handleMatchFound(matchId, isHost: true);
     }
     // If null, we wait for the poll loop to pick up that someone else succeeded (status == 'matched')
  }

  Future<void> _startMatchmaking() async {
    try {
      // 1. Join Queue
      await _service.joinQueue();
      if (!mounted) return;

      setState(() => _statusMessage = "Waiting for players...");

      // 2. Poll status every 1 second (faster for countdown sync)
      _pollTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        final status = await _service.checkQueueStatus();
        
        if (!mounted) return;
        
        if (status['status'] == 'matched') {
           _cancelCountdown();
           // If we found it via poll, we are a CLIENT (someone else started it)
           _handleMatchFound(status['matchId'], isHost: false);
           return;
        }
        
        // Update avatars & Votes
        if (status['status'] == 'searching') {
          final avatars = List<String?>.from(status['avatars'] ?? []);
          final votes = List<bool>.from(status['hasVoted'] ?? []);
          final voteCount = status['votes'] as int? ?? 0;
          final totalCount = status['total'] as int? ?? 0;

          setState(() {
            _foundAvatars = avatars;
            _playersVoted = votes;
          });

          // Countdown Logic:
          // Start if: Total >= 2 AND All Voted
          if (totalCount >= 2 && voteCount == totalCount) {
             _startCountdown();
          } else {
             // If condition breaks (new player joined, or < 2), cancel
             if (_isCountdownActive) {
                _cancelCountdown();
             } else if (!_isCountdownActive) {
                // Update status message only if not counting down
                // If 4 players auto-start logic is still desired, we could keep it, 
                // but user asked for "Vote to start". Let's rely purely on voting for consistency.
                // Or maybe auto-vote for 4th player? 
                // User said: "if 4th person enters... causes a start". 
                // We'll simulate this by auto-triggering the countdown or vote.
                // For now, let's stick to explicitly voting to be safe, or auto-vote for everyone if 4.
                
                if (totalCount >= 4) {
                   // Auto-start immediate if 4 players? Or start countdown?
                   // User said "4th person... causes a 'start'".
                   // Let's just start the countdown immediately if 4 players are present.
                   // Actually, simplest implies: If 4 players, treat as if all voted?
                   // No, UI should show them voting.
                   // Let's stick to: "Vote status: X/Y"
                   setState(() => _statusMessage = "Waiting for votes ($voteCount/$totalCount)...");
                } else {
                   setState(() => _statusMessage = "Waiting for votes ($voteCount/$totalCount)...");
                }
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

  Future<void> _handleMatchFound(String matchId, {required bool isHost}) async {
    _pollTimer?.cancel();
    _cancelCountdown(); 
    _foundMatch = true;
    
    setState(() {
      _statusMessage = isHost ? "You are Host! Creating Match..." : "Match Found! Joining...";
    });
    
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    try {
      if (isHost) {
        debugPrint('👑 I am the host! creating game state for $matchId');
        ref.read(gameStateProvider.notifier).hostGame(matchId);
      } else {
        debugPrint('👋 I am a client! Joining game $matchId');
        ref.read(gameStateProvider.notifier).joinGame(matchId);
      }
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
                  final avatarUrl = index < _foundAvatars.length ? _foundAvatars[index] : null;
                  final isFilled = index < _foundAvatars.length;
                  final hasVoted = index < _playersVoted.length ? _playersVoted[index] : false;
                  return _buildPlayerSlot(isFilled, avatarUrl, hasVoted);
                }),
              ),
              
              const SizedBox(height: 24),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: GameTheme.textSecondary, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: const Text("Leave Queue"),
                  ),
                  const SizedBox(width: 16),
                  
                  // Vote Button (Only shows if there are players and I haven't voted/countdown not active)
                  if (_foundAvatars.length >= 2 && !_iHaveVoted && !_isCountdownActive)
                    ElevatedButton(
                      onPressed: () async {
                         setState(() => _iHaveVoted = true); // Optimistic Update
                         await _service.voteToStart();
                         // Vote recorded. Countdown will start when ALL votes are in (detected by poll)
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GameTheme.accent,
                        foregroundColor: GameTheme.textPrimary,
                      ),
                      child: const Text("Vote to Start"),
                    ),
                    
                  if (_iHaveVoted && !_isCountdownActive)
                    const Chip(
                      label: Text("Voted!", style: TextStyle(color: Colors.white)),
                      backgroundColor: Colors.green,
                    )
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildPlayerSlot(bool isFilled, String? avatarUrl, bool hasVoted) {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.black26,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isFilled ? GameTheme.accent : Colors.grey.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: isFilled
                  ? const CircleAvatar( // Use CircleAvatar for default icon if image fails
                      backgroundColor: Colors.transparent,
                      child: Icon(Icons.person, color: GameTheme.accent),
                    )
                  : const Icon(Icons.person_outline, color: Colors.grey),
            ),
            if (isFilled && avatarUrl != null && avatarUrl.isNotEmpty)
              Positioned.fill(
                child: ClipOval(
                  child: Image.network(
                    avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (c,e,s) => const SizedBox(),
                  ),
                ),
              ),
              
            // Vote Checkmark Overlay
            if (isFilled && hasVoted)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(4),
                  child: const Icon(Icons.check, size: 12, color: Colors.white),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
