/// State management for Nertz Royale

library;

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart' hide ConnectionState;
import '../../services/supabase_service.dart';
import '../../services/mission_service.dart';
import '../../services/matchmaking_service.dart'; // Added
import '../models/card.dart';
import 'package:nertz_royale/engine/bot_logic.dart';
import 'package:nertz_royale/state/bot_difficulty_provider.dart';
import 'package:nertz_royale/state/economy_provider.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/game_state.dart';
import '../models/player_state.dart';
import '../engine/game_engine.dart';
export '../network/protocol.dart';
import '../engine/move_validator.dart';
import '../network/game_client.dart' show ConnectionState, GameMessage;
import '../network/supabase_game_client.dart';
import '../network/protocol.dart';
import '../ui/theme/game_theme.dart';

const _uuid = Uuid();
/// Player identity provider
final playerIdProvider = StateProvider<String>((ref) => _uuid.v4());
final playerNameProvider = StateProvider<String>((ref) => 'Player');

/// Accessibility settings
final highContrastModeProvider = StateProvider<bool>((ref) => false);
final cardStyleProvider = Provider<CardStyle>((ref) {
  final highContrast = ref.watch(highContrastModeProvider);
  return highContrast ? CardStyle.highContrast : CardStyle.normal;
});

/// Connection state
final connectionStateProvider = StateProvider<ConnectionState>((ref) {
  return ConnectionState.disconnected;
});

/// Game Client Provider
final gameClientProvider = Provider<SupabaseGameClient>((ref) {
  final id = ref.watch(playerIdProvider);
  final name = ref.watch(playerNameProvider);
  return SupabaseGameClient(playerId: id, displayName: name);
});

/// Current match ID
final matchIdProvider = StateProvider<String?>((ref) => null);

class GameStateNotifier extends StateNotifier<GameState?> {
  final String playerId;
  final String playerName;
  final SupabaseGameClient client;
  final Ref ref; // Added for accessing bot difficulty
  Timer? _botTimer;
  final Map<String, DateTime> _botVoteSchedule = {};
  final Map<String, DateTime> _botCenterPileSpotted = {}; // Tracks when bots first spot a center pile opportunity
  
  
  GameStateNotifier({
    required this.playerId, 
    required this.playerName,
    required this.client,
    required this.ref,
  }) : super(null);
  
  @override
  void dispose() {
    _botTimer?.cancel();
    super.dispose();
  }

  void _startBotLoop() {
    _botTimer?.cancel();
    debugPrint('🤖 Starting bot loop...');
    // Get bot difficulty from provider (default: medium = 2500ms)
    final difficulty = ref.read(botDifficultyProvider);
    final delayMs = difficulty.delayMs;
    debugPrint('🤖 Bot difficulty: ${difficulty.displayName} (${delayMs}ms delay)');
    
    _botTimer = Timer.periodic(Duration(milliseconds: delayMs), (timer) {
      if (state == null || state!.phase != GamePhase.playing) {
        return;
      }
      
      // Wait for countdown (4 seconds)
      if (state!.roundStartTime != null) {
        final elapsed = DateTime.now().difference(state!.roundStartTime!);
        if (elapsed.inSeconds < 4) return;
      }
      
      final bots = state!.players.values.where((p) => p.isBot).toList();
      if (bots.isEmpty) return;

      // Check for reset votes and handle bot voting
      if (state!.resetVotes.isNotEmpty) {
        for (final bot in bots) {
          if (!state!.resetVotes.contains(bot.id)) {
            // Determine reaction time if not already scheduled
            if (!_botVoteSchedule.containsKey(bot.id)) {
               final delay = Random().nextInt(16) + 10; // 10-25 seconds
               _botVoteSchedule[bot.id] = DateTime.now().add(Duration(seconds: delay));
            }
            
            // Check if it's time to vote
            if (DateTime.now().isAfter(_botVoteSchedule[bot.id]!)) {
              // Check condition: Has the voting player(s) been inactive for 3 mins?
              // We check if *any* human voter is "stuck" (inactive > 3 mins)
              final votingHumans = state!.resetVotes.where((id) => !state!.players[id]!.isBot);
              final isSomeoneStuck = votingHumans.any((id) {
                final p = state!.players[id];
                if (p == null) return false;
                if (p.lastMoveTime == null) return true; // Never moved
                return DateTime.now().difference(p.lastMoveTime!).inSeconds >= 60; // 1 minute
              });

              // If someone is genuinely stuck (or we are stuck), vote YES
              // Or if we are also stuck
              final amIStuck = bot.stockPile.isEmpty && bot.wastePile.isEmpty && BotLogic.findBestMove(state!, bot.id) == null;
              
              if (isSomeoneStuck || amIStuck) {
                 executeMove(Move(type: MoveType.voteReset, playerId: bot.id));
              }
            }
          }
        }
      } else {
        // Clear schedule if no votes active
        _botVoteSchedule.clear();
      }
      
      for (final bot in bots) {
        // SAFETY: Check if round ended (another player won)
        if (state == null || state!.phase != GamePhase.playing) {
          break; // Exit bot loop immediately if round is over
        }
        
        // 1. Try to find a move
        final move = BotLogic.findBestMove(state!, bot.id);
        if (move != null) {
          // Check if this is a center pile move - apply hesitation delay
          if (move.type == MoveType.toCenter) {
            // Track when we first spotted this center pile opportunity
            final botCenterKey = '${bot.id}_center';
            if (!_botCenterPileSpotted.containsKey(botCenterKey)) {
              _botCenterPileSpotted[botCenterKey] = DateTime.now();
            }
            
            // Calculate required hesitation based on difficulty
            final difficulty = ref.read(botDifficultyProvider);
            final hesitationMs = difficulty.centerPileDelayMs;
            final spottedTime = _botCenterPileSpotted[botCenterKey]!;
            final elapsed = DateTime.now().difference(spottedTime).inMilliseconds;
            
            if (elapsed < hesitationMs) {
              // Still hesitating - skip this bot for now
              continue;
            }
            
            // Hesitation complete - execute and clear
            _botCenterPileSpotted.remove(botCenterKey);
          }
          
          executeMove(move);
          
          // SAFETY: Re-check phase after move (round may have ended)
          if (state == null || state!.phase != GamePhase.playing) {
            break;
          }
          
          // Bots don't need to press the button - auto-win if Nertz pile empty
          // Fetch updated state for this bot
          final updatedBot = state!.players[bot.id];
          if (updatedBot != null && updatedBot.nertzPile.isEmpty) {
            executeMove(Move(type: MoveType.callNertz, playerId: bot.id));
          }
        } else {
          // Clear any pending center pile tracking if no move available
          _botCenterPileSpotted.remove('${bot.id}_center');
          
          // 2. If no move...
          
          // Check if we should vote for reset independently (if stock/waste empty and no moves)
          // This logic now supplements the "agreeing" logic above
          if (!state!.resetVotes.contains(bot.id)) {
             if (bot.stockPile.isEmpty && bot.wastePile.isEmpty) {
                // Determine if we are genuinely stuck (no moves at all)
                executeMove(Move(type: MoveType.voteReset, playerId: bot.id));
             }
          }

          // Draw cards logic (if not empty)
          if (!(bot.stockPile.isEmpty && bot.wastePile.isEmpty)) {
             if (DateTime.now().millisecondsSinceEpoch % 2 == 0) {
               drawThree(bot.id);
             }
          }
        }
      }
    });
  }
  
  Future<void> createLocalGame() async {
    final matchId = SupabaseGameClient.generateMatchId();
    
    // Fetch user's XP for correct rank display
    int totalXp = 0;
    try {
      final profile = await SupabaseService().getProfile();
      if (profile != null) {
        totalXp = (profile['total_xp'] as int?) ?? 0;
      }
    } catch (e) {
      debugPrint('Error fetching XP for local game: $e');
    }

    final newState = GameState.newMatch(matchId, playerId, playerName, hostTotalXp: totalXp);
    
    // Get settings from providers
    final botCount = ref.read(botCountProvider);
    final maxRounds = ref.read(roundsToPlayProvider);
    
    // Store max rounds in game state
    newState.maxRounds = maxRounds;
    
    // Add bots based on setting (1-3 bots)
    final botNames = ['Bot Dewy', 'Bot Aaron', 'Bot Adam'];
    final availableAvatars = [
      'assets/avatars/avatar1.jpg',
      'assets/avatars/avatar2.jpg',
      'assets/avatars/avatar3.jpg',
      'assets/avatars/avatar4.jpg',
      'assets/avatars/avatar5.jpg',
      'assets/avatars/avatar6.jpg',
      'assets/avatars/avatar7.jpg',
      'assets/avatars/avatar8.jpg',
      'assets/avatars/avatar9.jpg',
    ];
    
    // Shuffle avatars to get random ones
    final random = Random();
    final shuffledAvatars = List<String>.from(availableAvatars)..shuffle(random);

    for (int i = 0; i < botCount; i++) {
      final avatarUrl = i < shuffledAvatars.length ? shuffledAvatars[i] : availableAvatars[i % availableAvatars.length];
      newState.addPlayer('ai_${i + 1}', botNames[i], isBot: true, avatarUrl: avatarUrl);
    }
    
    // Assign colors for the match (will persist across rounds)
    _assignPlayerColors(newState);
    
    newState.startRound();
    state = newState; // Trigger listeners once
    _startBotLoop();
  }
  
  void _assignPlayerColors(GameState gameState) {
    final playerIds = gameState.players.keys.toList();
    final colors = [
      Color(0xFF2196F3), // Blue
      Color(0xFFF44336), // Red
      Color(0xFF4CAF50), // Green
      Color(0xFFFF9800), // Orange
    ];
    
    for (int i = 0; i < playerIds.length; i++) {
      final playerId = playerIds[i];
      final player = gameState.players[playerId]!;
      final color = colors[i % colors.length];
      gameState.players[playerId] = player.copyWith(playerColor: color.value);
    }
  }
  
  void joinGame(String matchId) async {
    debugPrint('🌐 joinGame called with matchId: $matchId');
    
    // Fetch card back
    String? cardBack;
    try {
      cardBack = await ref.read(selectedCardBackProvider.future);
    } catch (e) {
      debugPrint('⚠️ Failed to fetch card back: $e');
    }
    
    // Fetch profile for avatar
    String? avatarUrl;
    try {
      final profile = await SupabaseService().getProfile();
      avatarUrl = profile?['avatar_url'];
    } catch (e) {
      debugPrint('⚠️ Failed to fetch profile avatar: $e');
    }
    
    client.joinMatch(matchId, selectedCardBack: cardBack, avatarUrl: avatarUrl);
    
    // Send immediate request after a short delay for channel to establish
    Future.delayed(const Duration(milliseconds: 500), () {
      if (state == null) {
        debugPrint('🌐 Sending immediate RequestStateMessage...');
        client.send(RequestStateMessage(matchId: matchId, playerId: playerId));
      }
    });
    
    // Start retry timer to request state until we have it
    Timer.periodic(const Duration(seconds: 2), (timer) {
      if (state != null || client.connectionState == ConnectionState.disconnected) {
        debugPrint('🌐 Retry timer cancelled. state: ${state != null}, connected: ${client.connectionState}');
        timer.cancel();
        return;
      }
      debugPrint('🌐 Retrying RequestStateMessage...');
      client.send(RequestStateMessage(matchId: matchId, playerId: playerId));
    });
  }
  
  void hostGame([String? matchId, bool autoStart = false]) async {
    // For P2P, host uses provided code or generates one
    final id = matchId ?? SupabaseGameClient.generateMatchId();
    debugPrint('🏠 hostGame called. Using matchId: $id, autoStart: $autoStart');
    
    // Fetch card back
    String? cardBack;
    try {
      cardBack = await ref.read(selectedCardBackProvider.future);
    } catch (e) {
      debugPrint('⚠️ Failed to fetch card back: $e');
    }

    // Fetch profile for avatar
    String? avatarUrl;
    try {
      final profile = await SupabaseService().getProfile();
      avatarUrl = profile?['avatar_url'];
    } catch (e) {
      debugPrint('⚠️ Failed to fetch profile avatar: $e');
    }

    state = GameState.newMatch(id, playerId, playerName, hostSelectedCardBack: cardBack, hostAvatarUrl: avatarUrl, isRanked: autoStart);
    
    debugPrint('🏠 GameState created. hostId: ${state!.hostId}');
    joinGame(id);
    
    // IMPORTANT: Broadcast state periodically for a few seconds to ensure clients receive it
    int broadcastCountdown = 5;
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (broadcastCountdown <= 0 || state == null || state!.phase == GamePhase.playing) {
        timer.cancel();
        return;
      }
      debugPrint('📢 Host Broadcasting State (${broadcastCountdown}s remaining)...');
      client.send(StateSnapshotMessage(gameState: state!));
      broadcastCountdown--;
    });
    
    // AUTO-START: For ranked matchmaking, start the game after a brief delay
    if (autoStart) {
      Future.delayed(const Duration(seconds: 3), () {
        if (state != null && state!.phase == GamePhase.lobby) {
          debugPrint('🚀 Auto-starting ranked game!');
          startNewRound();
        }
      });
    }
  }
  
  void handleMessage(GameMessage message) {
    debugPrint('📨 handleMessage received: ${message.runtimeType}');
    if (message is StateSnapshotMessage) {
      debugPrint('📨 Received StateSnapshotMessage! Players: ${message.gameState.players.keys.toList()}');
      state = message.gameState;
    } else if (message is MoveIntentMessage) {
      // Only execute moves from OTHER players (own moves are optimistic)
      if (state != null && message.move.playerId != playerId) {
        debugPrint('📨 Executing remote move from ${message.move.playerId}');
        try {
          final result = GameEngine.executeMove(message.move, state!);
          
          // CRITICAL: Check if remote move ended the round
          if (result.roundEnded && result.roundWinnerId != null) {
            debugPrint('🏁 Remote move ended round! Winner: ${result.roundWinnerId}');
            endRound(result.roundWinnerId!); 
            // Note: endRound will recreate state
          } else {
             // If round didn't end, just rebuild state to notify listeners of card move
             state = GameState.fromJson(state!.toJson());
          }

          // Check for unanimous reset vote after remote vote (Host Only)
          if (message.move.type == MoveType.voteReset && 
              state!.hostId == playerId &&
              state!.phase == GamePhase.playing && // Only reset if playing
              state!.hasUnanimousResetVote) {
            debugPrint('🔄 Unanimous vote from remote player! Resetting decks...');
            state!.executeReset();
            // Broadcast the new randomized state immediately
            client.send(StateSnapshotMessage(gameState: state!));
          }
        } catch (e, stack) {
          debugPrint('⚠️ Error executing remote move: $e');
          debugPrint(stack.toString());
          // Ignore malformed move to prevent crash
        }
      }
    } else if (message is JoinMatchMessage) {
      debugPrint('📨 JoinMatchMessage from ${message.displayName} (${message.playerId})');
      if (state != null) {
        if (!state!.players.containsKey(message.playerId)) {
          debugPrint('📨 Adding player to state: ${message.displayName} with avatar: ${message.avatarUrl}');
          state!.addPlayer(
            message.playerId, 
            message.displayName, 
            avatarUrl: message.avatarUrl,
            selectedCardBack: message.selectedCardBack,
          );
          state = GameState.fromJson(state!.toJson());
        }
        
        // If we are host, broadcast current state to joiner
        if (state!.hostId == playerId) {
          debugPrint('📨 I am host. Sending StateSnapshotMessage to joiner...');
          client.send(StateSnapshotMessage(gameState: state!));
        }
      } else {
        debugPrint('📨 JoinMatchMessage received but state is null!');
      }
    } else if (message is RequestStateMessage) {
      debugPrint('📨 RequestStateMessage received. Am I host? ${state?.hostId == playerId}');
      if (state != null && state!.hostId == playerId) {
        debugPrint('📨 Responding with StateSnapshotMessage...');
        client.send(StateSnapshotMessage(gameState: state!));
      }
    } else if (message is LeaveMatchMessage) {
      debugPrint('👋 Player ${message.playerId} left the match');
      if (state != null) {
        // Remove player from state
        state!.removePlayer(message.playerId);
        // Force update UI
        state = GameState.fromJson(state!.toJson());
        
        // CHECK FOR DEFAULT WIN (Last Player Standing)
        // If Ranked Game + Playing Phase + Only 1 player left
        if (state!.isRanked && 
            state!.phase == GamePhase.playing && 
            state!.players.length == 1) {
              
           final survivorId = state!.players.keys.first;
           debugPrint('🏆 Last Player Standing! Triggering Default Win for $survivorId');
           
           // End round immediately with default win flag
           endRound(survivorId, isDefaultWin: true);
        }
      }
    } else if (message is StartGameMessage) {
      debugPrint('📨 StartGameMessage received! Ensuring state sync...');
      // Critical: Do NOT shuffle locally (startRound). Wait for StateSnapshot.
      // If we are still in lobby, request state to be safe.
      if (state != null && state!.phase == GamePhase.lobby) {
        debugPrint('📨 Still in lobby phase. Requesting state snapshot from host...');
        client.send(RequestStateMessage(matchId: state!.matchId, playerId: playerId));
      }
    }
  }
  
  MoveResult executeMove(Move move) {
    if (state == null) {
      return MoveResult.invalid(move, 'No active game');
    }
    
    final validation = MoveValidator.validate(move, state!);
    if (!validation.isValid) {
      return validation;
    }
    
    // Execute locally (optimistic)
    final result = GameEngine.executeMove(move, state!);
    
    // Update lastMoveTime ONLY for meaningful moves (center pile or from nertz pile)
    // Stock taps/draws do NOT count as activity for reset vote purposes
    if (state != null && state!.players.containsKey(move.playerId)) {
       final type = move.type;
       final now = DateTime.now();
       final p = state!.players[move.playerId]!;
       
       // Only count: toCenter moves (which includes nertz pile plays)
       if (type == MoveType.toCenter) {
          state!.players[move.playerId] = p.copyWith(
            lastMoveTime: now,
            lastPlayableActionTime: now,
          );
       }
       // Also track toWorkPile moves for shuffle timer
       else if (type == MoveType.toWorkPile) {
          state!.players[move.playerId] = p.copyWith(
            lastPlayableActionTime: now,
          );
       }
       // Reset lastPlayableActionTime after shuffling
       else if (type == MoveType.shuffleDeck) {
          state!.players[move.playerId] = p.copyWith(
            lastPlayableActionTime: now,
          );
       }
    }
    
    // CRITICAL: Create new state reference BEFORE endRound mutation.
    // This ensures Riverpod sees the old phase in 'previous' before we mutate.
    state = GameState.fromJson(state!.toJson());
    
    if (result.roundEnded && result.roundWinnerId != null) {
      // Now mutate the NEW state object (not the one Riverpod cached as 'previous')
      state!.endRound(result.roundWinnerId!);
      // Create another new reference to trigger notification with updated phase
      state = GameState.fromJson(state!.toJson());
    }
      
      // XP and Win logic moved to GameScreen listener to ensure it runs for all players
      // regardless of who triggered the round/match end.
    
    // Special handling for Vote Reset (Host Only)
    if (move.type == MoveType.voteReset && 
        state!.hostId == playerId && 
        state!.hasUnanimousResetVote) {
      debugPrint('🔄 Unanimous vote! Resetting decks...');
      state!.executeReset();
      // Important: Broadcast the new randomized state immediately
      client.send(StateSnapshotMessage(gameState: state!));
      state = GameState.fromJson(state!.toJson());
    }
    
    // Send to network
    client.sendMove(move);
    
    client.updateState(state!); // Keep client in sync
    
    return validation;
  }
  
  void drawThree(String playerId) {
    executeMove(Move(
      type: MoveType.drawThree,
      playerId: playerId,
    ));
  }

  void drawOne(String playerId) {
    executeMove(Move(
      type: MoveType.drawOne,
      playerId: playerId,
    ));
  }

  void voteForReset() {
    executeMove(Move(
      type: MoveType.voteReset,
      playerId: playerId,
    ));
  }
  
  void shuffleDeck() {
    executeMove(Move(
      type: MoveType.shuffleDeck,
      playerId: playerId,
    ));
  }
  
  bool autoMove(String cardId, String playerId) {
    if (state == null) return false;
    
    final bestMove = MoveValidator.getBestAutoMove(cardId, playerId, state!);
    if (bestMove != null) {
      executeMove(bestMove);
      return true;
    }
    return false;
  }
  
  void startNewRound() {
    if (state != null && 
        (state!.phase == GamePhase.roundEnd || state!.phase == GamePhase.lobby)) {
      state!.startRound();
      state = GameState.fromJson(state!.toJson());
      
      // Broadcast the shuffled state to all players so they have the same decks
      debugPrint('🏠 Broadcasting initial game state to all players...');
      client.send(StateSnapshotMessage(gameState: state!));
      
      client.startGame(state!.matchId);
    }
  }
  
  void endRound(String winnerId, {bool isDefaultWin = false}) {
    if (state == null) return;
    
    // Mission Tracking
    final currentPlayerId = client.playerId;
    if (currentPlayerId != null) {
      // Track game played for everyone
      MissionService().trackGamePlayed();
      
      // Track win/nertz call for winner
      final isWin = winnerId == currentPlayerId;
      if (isWin) {
        final duration = state!.roundStartTime != null 
            ? DateTime.now().difference(state!.roundStartTime!).inSeconds 
            : null;
            
        MissionService().trackWin(durationSeconds: duration);
        MissionService().trackNertzCall();
      }
    }
      


    state!.endRound(winnerId);
    state = GameState.fromJson(state!.toJson()); // Notify listeners
    
    // Sync state if host
    if (state!.hostId == client.playerId) {
      debugPrint('📢 Host Broadcasting Round End State...');
      client.send(StateSnapshotMessage(gameState: state!)); // FORCE sync
      client.updateState(state!);
    }
    
    // Ranked Points Update (ONLY for ranked games)
    if (state!.isRanked) {
      final pId = client.playerId;
      if (pId != null && state!.players.containsKey(pId)) {
         final playerState = state!.players[pId]!;
         // Calculate placement based on total score
         final allPlayers = state!.players.values.toList();
         allPlayers.sort((a, b) => b.scoreTotal.compareTo(a.scoreTotal)); // Descending
         final placement = allPlayers.indexWhere((p) => p.id == pId) + 1;
         
         // Report to backend
         MatchmakingService().reportRankedMatchResult(
           placement: placement,
           totalPoints: playerState.scoreTotal,
           bonusOverride: isDefaultWin ? 25 : null, // Default Win = +25 Override
         );
      }
    }
  }
  
  void reset() {
    debugPrint('🚨 RESET CALLED! State being set to null');
    debugPrint('Stack trace: ${StackTrace.current}');
    state = null;
    client.disconnect();
  }
}

/// Game state provider
final gameStateProvider = StateNotifierProvider<GameStateNotifier, GameState?>((ref) {
  // IMPORTANT: Use ref.read (not ref.watch) to prevent provider recreation
  // when these values change. We only need them at initialization time.
  final playerId = ref.read(playerIdProvider);
  final playerName = ref.read(playerNameProvider);
  final client = ref.read(gameClientProvider);
  
  final notifier = GameStateNotifier(
    playerId: playerId, 
    playerName: playerName,
    client: client,
    ref: ref,
  );
  
  // Wire up callbacks
  client.onMessage = notifier.handleMessage;
  client.onConnectionChanged = (connected) {
    ref.read(connectionStateProvider.notifier).state = 
        connected ? ConnectionState.connected : ConnectionState.disconnected;
  };
  
  return notifier;
});

/// Current player state (derived)
final currentPlayerProvider = Provider<PlayerState?>((ref) {
  final gameState = ref.watch(gameStateProvider);
  final playerId = ref.watch(playerIdProvider);
  
  return gameState?.getPlayer(playerId);
});

/// Available moves for current player
final availableMovesProvider = Provider<List<Move>>((ref) {
  final gameState = ref.watch(gameStateProvider);
  final playerId = ref.watch(playerIdProvider);
  
  if (gameState == null || gameState.phase != GamePhase.playing) {
    return [];
  }
  
  return MoveValidator.getValidMoves(playerId, gameState);
});

/// Game phase
final gamePhaseProvider = Provider<GamePhase?>((ref) {
  return ref.watch(gameStateProvider)?.phase;
});

/// Leaderboard
final leaderboardProvider = Provider<List<PlayerState>>((ref) {
  return ref.watch(gameStateProvider)?.leaderboard ?? [];
});
