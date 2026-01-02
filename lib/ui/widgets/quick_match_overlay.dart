import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/matchmaking_service.dart';
import '../theme/game_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/game_provider.dart';
import '../screens/game_screen.dart';

class QuickMatchOverlay extends ConsumerStatefulWidget {
  const QuickMatchOverlay({super.key});

  @override
  ConsumerState<QuickMatchOverlay> createState() => _QuickMatchOverlayState();
}

class _QuickMatchOverlayState extends ConsumerState<QuickMatchOverlay> {
  Timer? _pollTimer;
  Timer? _countdownTimer;
  Timer? _heartbeatTimer;
  String _statusMessage = "Joining queue...";
  final _service = MatchmakingService();
  bool _foundMatch = false;
  bool _isFinalized = false; // Prevents restart after countdown ends
  List<String?> _foundAvatars = [];
  List<bool> _playersVoted = [];
  int _countdown = 10;
  bool _isCountdownActive = false;
  bool _iHaveVoted = false;

  @override
  void initState() {
    super.initState();
    _startMatchmaking();
    _startHeartbeat();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    _heartbeatTimer?.cancel();
    if (!_foundMatch) {
      // IMPORTANT: Leave queue when overlay closes
      _service.leaveQueue();
    }
    super.dispose();
  }
  
  /// Heartbeat: Updates our queue entry every 10s so DB knows we're alive
  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (!mounted || _foundMatch) {
        timer.cancel();
        return;
      }
      await _service.sendHeartbeat();
    });
  }

  void _startCountdown() {
    if (_isCountdownActive || _isFinalized) return;
    
    // Cancel poll timer during countdown to prevent interference
    _pollTimer?.cancel();
    
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
        timer.cancel();
        _countdownTimer = null;
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
     _isFinalized = true; // Prevent any restart of countdown
     
     setState(() { 
       _isCountdownActive = false;
       _statusMessage = "Launching...";
     });
     
     // Calculate minimum opponents based on current players
     // _foundAvatars includes us, so opponents = total - 1
     final minOpponents = (_foundAvatars.length - 1).clamp(1, 3);
     
     debugPrint('🚀 Finalizing match with ${_foundAvatars.length} players (minOpponents: $minOpponents)');
     
     // Trigger the match creation.
     final matchId = await _service.tryCreateMatch(minOpponents: minOpponents);
     if (matchId != null) {
       debugPrint('✅ Match created: $matchId - I am HOST');
       _handleMatchFound(matchId, isHost: true);
     } else {
       debugPrint('⏳ Match creation failed, waiting for host...');
       // If failed, resume polling to detect if someone else created the match
       setState(() => _statusMessage = "Waiting for host...");
       _resumePolling();
     }
  }
  
  void _resumePolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final status = await _service.checkQueueStatus();
      if (!mounted) return;
      
      if (status['status'] == 'matched') {
        timer.cancel();
        _handleMatchFound(status['matchId'], isHost: false);
      }
    });
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

          // AUTO-START: 4 players = instant start (no voting needed)
          if (totalCount >= 4) {
            final matchId = await _service.tryCreateMatch();
            if (matchId != null) {
              _handleMatchFound(matchId, isHost: true);
            }
            return; // Exit poll callback
          }
          
          // MAJORITY VOTE: 2-3 players need majority to start countdown
          // 2 players: 2/2 needed (both)
          // 3 players: 2/3 needed
          final majorityThreshold = (totalCount / 2).ceil();
          final hasMajority = voteCount >= majorityThreshold && totalCount >= 2;
          
          if (hasMajority) {
             _startCountdown();
          } else {
             // If condition breaks (new player joined, or < 2), cancel
             if (_isCountdownActive) {
                _cancelCountdown();
             } else {
                setState(() => _statusMessage = "Waiting for votes ($voteCount/$totalCount)...");
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
        // Auto-start for ranked matches - skip lobby screen
        ref.read(gameStateProvider.notifier).hostGame(matchId, true);
      } else {
        debugPrint('👋 I am a client! Joining game $matchId');
        ref.read(gameStateProvider.notifier).joinGame(matchId);
      }
      
      // Close overlay and navigate to game screen
      Navigator.pop(context);
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const GameScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
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
