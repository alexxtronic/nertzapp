import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/game_state.dart';
import '../engine/move_validator.dart'; // For Move
import 'game_client.dart'; // For enums/typedefs (also provides protocol exports)
import '../services/supabase_service.dart'; // To access lobby stream

class SupabaseGameClient {
  static final _uuid = const Uuid();
  
  final String playerId;
  final String displayName;
  
  RealtimeChannel? _channel;
  ConnectionState _connectionState = ConnectionState.disconnected;
  int _sequenceNumber = 0;
  final Map<int, Move> _pendingMoves = {};
  GameState? _localState;
  
  OnMessageCallback? onMessage;
  OnConnectionCallback? onConnectionChanged;
  OnErrorCallback? onError;
  
  SupabaseGameClient({
    required this.playerId,
    required this.displayName,
  });
  
  ConnectionState get connectionState => _connectionState;
  bool get isConnected => _connectionState == ConnectionState.connected;
  GameState? get localState => _localState;
  
  Future<bool> connect() async {
    // Supabase client is global, so "connect" here really means "ready to join channels"
    // or we can verify Supabase connection status.
    _connectionState = ConnectionState.connected;
    onConnectionChanged?.call(true);
    return true;
  }
  
  void disconnect() {
    _channel?.unsubscribe();
    _channel = null;
    _connectionState = ConnectionState.disconnected;
    onConnectionChanged?.call(false);
  }
  
  void joinMatch(String matchId, {String? selectedCardBack, String? avatarUrl}) {
    debugPrint('📡 joinMatch subscribing to channel: game:$matchId');
    if (_channel != null) {
      _channel!.unsubscribe();
    }

    final supabase = Supabase.instance.client;
    
    // Subscribe to the game channel
    _channel = supabase.channel('game:$matchId', opts: const RealtimeChannelConfig(self: true));
    
    _channel!
      .onBroadcast(event: 'game_message', callback: (payload) {
        // Supabase may wrap the payload - check for nested 'payload' key
        Map<String, dynamic> actualPayload = payload;
        if (payload.containsKey('payload') && payload['payload'] is Map) {
          debugPrint('📡 Unwrapping nested payload...');
          actualPayload = Map<String, dynamic>.from(payload['payload']);
        }
        
        _handleMessage(actualPayload);
      })
      .onPresenceSync((payload) {
        // Handle presence sync if we want to track online users via Presence
        // For now, rely on GameMessage protocol
      })
      .subscribe((status, error) {
        debugPrint('📡 Channel subscription status: $status, error: $error');
        if (status == RealtimeSubscribeStatus.subscribed) {
           _connectionState = ConnectionState.connected;
           onConnectionChanged?.call(true);
           
           // Send Join Message via Broadcast
           debugPrint('📡 Sending JoinMatchMessage...');
           send(JoinMatchMessage(
             matchId: matchId, 
             playerId: playerId, 
             displayName: displayName,
             selectedCardBack: selectedCardBack,
             avatarUrl: avatarUrl,
           ));
        } else if (status == RealtimeSubscribeStatus.closed) {
           _connectionState = ConnectionState.disconnected;
           onConnectionChanged?.call(false);
        }
      });


    // Also listen to the Lobby row for "Start Game" signal (Source of Truth)
    SupabaseService().streamLobby(matchId).listen((lobbyData) {
      if (lobbyData['status'] == 'playing') {
        debugPrint('📡 DB says Game Started! Synthesizing StartGameMessage...');
        
        // Check if we are already playing to avoid loops
        if (_localState != null && _localState!.phase != GamePhase.playing) {
           onMessage?.call(StartGameMessage(matchId: matchId, hostId: 'server'));
        }
      }
    });
  }
  
  void leaveMatch(String matchId) {
    send(LeaveMatchMessage(matchId: matchId, playerId: playerId));
    Future.delayed(const Duration(milliseconds: 500), () {
      disconnect();
    });
  }
  
  void setReady(bool isReady) {
    send(SetReadyMessage(playerId: playerId, isReady: isReady));
  }
  
  void startGame(String matchId) {
    // OLD: send(StartGameMessage(matchId: matchId, hostId: playerId));
    // NEW: Update Database (Server Authoritative)
    debugPrint('📡 Host starting game via Database update...');
    SupabaseService().updateLobbyStatus(matchId, 'playing');
  }
  
  void sendMove(Move move, {bool optimistic = true}) {
    final seqNum = ++_sequenceNumber;
    _pendingMoves[seqNum] = move;
    
    // Note: Optimistic execution is handled by GameStateNotifier
    send(MoveIntentMessage(move: move, sequenceNumber: seqNum));
  }
  
  void send(GameMessage message) {
    if (_channel == null) return;
    
    final json = message.toJson();
    json['msgType'] = message.type.index;
    
    _channel!.sendBroadcastMessage(
      event: 'game_message',
      payload: json,
    );
  }
  
  void updateState(GameState state) {
    _localState = state;
  }
  
  void _handleMessage(Map<String, dynamic> json) {
    try {
      final message = GameMessage.decode(json);
      
      if (message != null) {
        onMessage?.call(message);
      }
    } catch (e) {
      onError?.call('Failed to parse message: $e');
    }
  }

  static String generateMatchId() {
    // Generate 6-digit numeric code (100000-999999)
    // Matches SupabaseService logic for consistency
    final code = (100000 + DateTime.now().microsecondsSinceEpoch % 899999).toString();
    return code;
  }
}
