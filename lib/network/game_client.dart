/// Game client for Nertz Royale

library;

import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';

import '../models/game_state.dart';
import '../engine/move_validator.dart';
import '../engine/game_engine.dart';
import 'protocol.dart';
export 'protocol.dart';

typedef OnMessageCallback = void Function(GameMessage message);
typedef OnConnectionCallback = void Function(bool connected);
typedef OnErrorCallback = void Function(String error);

enum ConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

class GameClient {
  static final _uuid = Uuid();
  
  final String serverUrl;
  final String playerId;
  final String displayName;
  
  WebSocketChannel? _channel;
  ConnectionState _connectionState = ConnectionState.disconnected;
  int _sequenceNumber = 0;
  final Map<int, Move> _pendingMoves = {};
  GameState? _localState;
  
  OnMessageCallback? onMessage;
  OnConnectionCallback? onConnectionChanged;
  OnErrorCallback? onError;
  
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  static const _pingInterval = Duration(seconds: 30);
  static const _reconnectDelay = Duration(seconds: 3);
  
  GameClient({
    required this.serverUrl,
    required this.playerId,
    required this.displayName,
  });
  
  ConnectionState get connectionState => _connectionState;
  bool get isConnected => _connectionState == ConnectionState.connected;
  GameState? get localState => _localState;
  
  Future<bool> connect() async {
    if (_connectionState == ConnectionState.connected) return true;
    
    _connectionState = ConnectionState.connecting;
    onConnectionChanged?.call(false);
    
    try {
      _channel = WebSocketChannel.connect(Uri.parse(serverUrl));
      
      await _channel!.ready;
      
      _connectionState = ConnectionState.connected;
      onConnectionChanged?.call(true);
      
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
      );
      
      _startPingTimer();
      
      return true;
    } catch (e) {
      _connectionState = ConnectionState.disconnected;
      onError?.call('Failed to connect: $e');
      _scheduleReconnect();
      return false;
    }
  }
  
  void disconnect() {
    _stopPingTimer();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _connectionState = ConnectionState.disconnected;
    onConnectionChanged?.call(false);
  }
  
  void send(GameMessage message) {
    if (!isConnected) {
      onError?.call('Not connected');
      return;
    }
    
    final json = message.toJson();
    json['type'] = message.type.index;
    _channel!.sink.add(jsonEncode(json));
  }
  
  void joinMatch(String matchId) {
    send(JoinMatchMessage(
      matchId: matchId,
      playerId: playerId,
      displayName: displayName,
    ));
  }
  
  void leaveMatch(String matchId) {
    send(LeaveMatchMessage(matchId: matchId, playerId: playerId));
  }
  
  void setReady(bool isReady) {
    send(SetReadyMessage(playerId: playerId, isReady: isReady));
  }
  
  void startGame(String matchId) {
    send(StartGameMessage(matchId: matchId, hostId: playerId));
  }
  
  void sendMove(Move move, {bool optimistic = true}) {
    final seqNum = ++_sequenceNumber;
    _pendingMoves[seqNum] = move;
    
    if (optimistic && _localState != null) {
      GameEngine.executeMove(move, _localState!);
    }
    
    send(MoveIntentMessage(move: move, sequenceNumber: seqNum));
  }
  
  void updateState(GameState state) {
    _localState = state;
  }
  
  void _handleMessage(dynamic data) {
    try {
      final json = jsonDecode(data as String) as Map<String, dynamic>;
      final message = GameMessage.decode(json);
      
      if (message == null) {
        onError?.call('Unknown message type');
        return;
      }
      
      if (message is MoveAcceptedMessage) {
        _pendingMoves.remove(message.sequenceNumber);
      } else if (message is MoveRejectedMessage) {
        final rejectedMove = _pendingMoves.remove(message.sequenceNumber);
        if (rejectedMove != null) {
          onError?.call('Move rejected: ${message.reason}');
        }
      } else if (message is StateSnapshotMessage) {
        _localState = message.gameState;
        _pendingMoves.clear();
      } else if (message is GameStartMessage) {
        _localState = message.gameState;
        _pendingMoves.clear();
      } else if (message is PongMessage) {
        // Connection is healthy
      }
      
      onMessage?.call(message);
    } catch (e) {
      onError?.call('Failed to parse message: $e');
    }
  }
  
  void _handleError(dynamic error) {
    onError?.call('Connection error: $error');
    _handleDisconnect();
  }
  
  void _handleDisconnect() {
    _stopPingTimer();
    _connectionState = ConnectionState.disconnected;
    onConnectionChanged?.call(false);
    _scheduleReconnect();
  }
  
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () {
      if (_connectionState == ConnectionState.disconnected) {
        _connectionState = ConnectionState.reconnecting;
        connect();
      }
    });
  }
  
  void _startPingTimer() {
    _stopPingTimer();
    _pingTimer = Timer.periodic(_pingInterval, (_) {
      if (isConnected) {
        send(PingMessage());
      }
    });
  }
  
  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }
  
  static String generateMatchId() => _uuid.v4().substring(0, 8).toUpperCase();
  static String generatePlayerId() => _uuid.v4();
}
