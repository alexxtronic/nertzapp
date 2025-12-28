/// State management for Nertz Royale

library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../engine/bot_logic.dart';

// ... (imports remain)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/game_state.dart';
import '../models/player_state.dart';
import '../engine/game_engine.dart';
export '../network/protocol.dart'; // Export protocol.dart as requested
import '../engine/move_validator.dart';
import '../network/game_client.dart' show ConnectionState, GameMessage;
import '../network/supabase_game_client.dart';
import '../network/protocol.dart';
import '../ui/theme/game_theme.dart';
import '../ui/widgets/game_board.dart';

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

/// Game state notifier
class GameStateNotifier extends StateNotifier<GameState?> {
  final String playerId;
  final String playerName;
  final SupabaseGameClient client;
  Timer? _botTimer;
  
  GameStateNotifier({
    required this.playerId, 
    required this.playerName,
    required this.client,
  }) : super(null);
  
  @override
  void dispose() {
    _botTimer?.cancel();
    super.dispose();
  }

  void _startBotLoop() {
    _botTimer?.cancel();
    debugPrint('🤖 Starting bot loop...');
    // 400ms interval = 60% faster than 800ms
    _botTimer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      if (state == null || state!.phase != GamePhase.playing) {
        return;
      }
      
      final bots = state!.players.values.where((p) => p.isBot).toList();
      if (bots.isEmpty) return;
      
      for (final bot in bots) {
        // 1. Try to find a move
        final move = BotLogic.findBestMove(state!, bot.id);
        if (move != null) {
          executeMove(move);
        } else {
          // 2. If no move, draw cards more frequently (every other tick)
          if (DateTime.now().millisecondsSinceEpoch % 2 == 0) {
             drawThree(bot.id);
          }
        }
      }
    });
  }
  
  void createLocalGame() {
    final matchId = SupabaseGameClient.generateMatchId();
    final newState = GameState.newMatch(matchId, playerId, playerName);
    
    // Add 3 bots for a full 4-player game
    newState.addPlayer('ai_1', 'Bot Alice', isBot: true);
    newState.addPlayer('ai_2', 'Bot Bob', isBot: true);
    newState.addPlayer('ai_3', 'Bot Charlie', isBot: true);
    
    newState.startRound();
    state = newState; // Trigger listeners once
    _startBotLoop();
  }
  
  void joinGame(String matchId) {
    debugPrint('🌐 joinGame called with matchId: $matchId');
    client.joinMatch(matchId);
    
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
  
  void hostGame([String? matchId]) async {
    // For P2P, host uses provided code or generates one
    final id = matchId ?? SupabaseGameClient.generateMatchId();
    debugPrint('🏠 hostGame called. Using matchId: $id');
    state = GameState.newMatch(id, playerId, playerName);
    debugPrint('🏠 GameState created. hostId: ${state!.hostId}');
    joinGame(id);
  }
  
  void handleMessage(GameMessage message) {
    debugPrint('📨 handleMessage received: ${message.runtimeType}');
    if (message is StateSnapshotMessage) {
      debugPrint('📨 Received StateSnapshotMessage! Players: ${message.gameState.players.keys.toList()}');
      state = message.gameState;
    } else if (message is MoveIntentMessage) {
      if (state != null) {
        GameEngine.executeMove(message.move, state!);
        state = GameState.fromJson(state!.toJson()); // Rebuild
      }
    } else if (message is JoinMatchMessage) {
      debugPrint('📨 JoinMatchMessage from ${message.displayName} (${message.playerId})');
      if (state != null) {
        if (!state!.players.containsKey(message.playerId)) {
          debugPrint('📨 Adding player to state...');
          state!.addPlayer(message.playerId, message.displayName);
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
    
    if (result.roundEnded && result.roundWinnerId != null) {
      GameEngine.endRound(state!, result.roundWinnerId!);
    }
    
    // Send to network
    client.sendMove(move);
    
    // Create a new reference to trigger Riverpod rebuild
    state = GameState.fromJson(state!.toJson());
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
      client.startGame(state!.matchId);
    }
  }
  
  void endRound(String winnerId) {
    if (state != null && state!.phase == GamePhase.playing) {
      state!.endRound(winnerId);
      state = GameState.fromJson(state!.toJson());
    }
  }
  
  void reset() {
    state = null;
    client.disconnect();
  }
}

/// Game state provider
final gameStateProvider = StateNotifierProvider<GameStateNotifier, GameState?>((ref) {
  final playerId = ref.watch(playerIdProvider);
  final playerName = ref.watch(playerNameProvider);
  final client = ref.watch(gameClientProvider);
  
  final notifier = GameStateNotifier(
    playerId: playerId, 
    playerName: playerName,
    client: client
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
