/// Network protocol for Nertz Royale

library;

import '../models/game_state.dart';
import '../engine/move_validator.dart';
import '../engine/scoring.dart';
import 'dart:convert'; // For jsonEncode

/// Message types for the game protocol
enum MessageType {
  joinMatch,
  leaveMatch,
  setReady,
  startGame,
  moveIntent,
  error,
  playerJoined,
  playerLeft,
  playerReady,
  gameStart,
  moveAccepted,
  moveRejected,
  stateSnapshot,
  roundEnd,
  matchEnd,
  ping,
  pong,
  requestState,
}

/// Base class for all messages
abstract class GameMessage {
  MessageType get type;
  
  Map<String, dynamic> toJson();
  
  String encode() {
    final json = toJson();
    json['msgType'] = type.index;  // Use 'msgType' to avoid Supabase 'type' collision
    return jsonEncode(json);
  }
  
  static GameMessage? decode(Map<String, dynamic> json) {
    try {
      // Use 'msgType' to avoid Supabase 'type' collision
      final rawType = json['msgType'];
      int typeIndex;
      if (rawType is int) {
        typeIndex = rawType;
      } else if (rawType is String) {
        typeIndex = int.tryParse(rawType) ?? -1;
      } else {
        print('⚠️ GameMessage.decode: Invalid msgType field: $rawType (json: $json)');
        return null;
      }
      
      if (typeIndex < 0 || typeIndex >= MessageType.values.length) {
        print('⚠️ GameMessage.decode: Type index out of bounds: $typeIndex');
        return null;
      }
      
      final type = MessageType.values[typeIndex];
      
      switch (type) {
        case MessageType.joinMatch:
          return JoinMatchMessage.fromJson(json);
        case MessageType.leaveMatch:
          return LeaveMatchMessage.fromJson(json);
        case MessageType.setReady:
          return SetReadyMessage.fromJson(json);
        case MessageType.startGame:
          return StartGameMessage.fromJson(json);
        case MessageType.moveIntent:
          return MoveIntentMessage.fromJson(json);
        case MessageType.error:
          return ErrorMessage.fromJson(json);
        case MessageType.playerJoined:
          return PlayerJoinedMessage.fromJson(json);
        case MessageType.playerLeft:
          return PlayerLeftMessage.fromJson(json);
        case MessageType.playerReady:
          return PlayerReadyMessage.fromJson(json);
        case MessageType.gameStart:
          return GameStartMessage.fromJson(json);
        case MessageType.moveAccepted:
          return MoveAcceptedMessage.fromJson(json);
        case MessageType.moveRejected:
          return MoveRejectedMessage.fromJson(json);
        case MessageType.stateSnapshot:
          return StateSnapshotMessage.fromJson(json);
        case MessageType.roundEnd:
          return RoundEndMessage.fromJson(json);
        case MessageType.matchEnd:
          return MatchEndMessage.fromJson(json);
        case MessageType.ping:
          return PingMessage();
        case MessageType.pong:
          return PongMessage();
        case MessageType.requestState:
          return RequestStateMessage.fromJson(json);
      }
    } catch (e, stack) {
      print('⚠️ GameMessage.decode error: $e');
      print('⚠️ Stack: $stack');
      print('⚠️ JSON was: $json');
      return null;
    }
  }
}

class JoinMatchMessage extends GameMessage {
  @override
  final MessageType type = MessageType.joinMatch;
  
  final String matchId;
  final String playerId;
  final String displayName;
  final String? selectedCardBack;
  final String? avatarUrl;
  
  JoinMatchMessage({
    required this.matchId,
    required this.playerId,
    required this.displayName,
    this.selectedCardBack,
    this.avatarUrl,
  });
  
  @override
  Map<String, dynamic> toJson() => {
    'matchId': matchId,
    'playerId': playerId,
    'displayName': displayName,
    'selectedCardBack': selectedCardBack,
    'avatarUrl': avatarUrl,
  };
  
  factory JoinMatchMessage.fromJson(Map<String, dynamic> json) => JoinMatchMessage(
    matchId: json['matchId'] as String,
    playerId: json['playerId'] as String,
    displayName: json['displayName'] as String,
    selectedCardBack: json['selectedCardBack'] as String?,
    avatarUrl: json['avatarUrl'] as String?,
  );
}

class LeaveMatchMessage extends GameMessage {
  @override
  final MessageType type = MessageType.leaveMatch;
  
  final String matchId;
  final String playerId;
  
  LeaveMatchMessage({required this.matchId, required this.playerId});
  
  @override
  Map<String, dynamic> toJson() => {
    'matchId': matchId,
    'playerId': playerId,
  };
  
  factory LeaveMatchMessage.fromJson(Map<String, dynamic> json) => LeaveMatchMessage(
    matchId: json['matchId'] as String,
    playerId: json['playerId'] as String,
  );
}

class SetReadyMessage extends GameMessage {
  @override
  final MessageType type = MessageType.setReady;
  
  final String playerId;
  final bool isReady;
  
  SetReadyMessage({required this.playerId, required this.isReady});
  
  @override
  Map<String, dynamic> toJson() => {
    'playerId': playerId,
    'isReady': isReady,
  };
  
  factory SetReadyMessage.fromJson(Map<String, dynamic> json) => SetReadyMessage(
    playerId: json['playerId'] as String,
    isReady: json['isReady'] as bool,
  );
}

class StartGameMessage extends GameMessage {
  @override
  final MessageType type = MessageType.startGame;
  
  final String matchId;
  final String hostId;
  
  StartGameMessage({required this.matchId, required this.hostId});
  
  @override
  Map<String, dynamic> toJson() => {
    'matchId': matchId,
    'hostId': hostId,
  };
  
  factory StartGameMessage.fromJson(Map<String, dynamic> json) => StartGameMessage(
    matchId: json['matchId'] as String,
    hostId: json['hostId'] as String,
  );
}

class MoveIntentMessage extends GameMessage {
  @override
  final MessageType type = MessageType.moveIntent;
  
  final Move move;
  final int sequenceNumber;
  
  MoveIntentMessage({required this.move, required this.sequenceNumber});
  
  @override
  Map<String, dynamic> toJson() => {
    'move': move.toJson(),
    'sequenceNumber': sequenceNumber,
  };
  
  factory MoveIntentMessage.fromJson(Map<String, dynamic> json) => MoveIntentMessage(
    move: Move.fromJson(json['move'] as Map<String, dynamic>),
    sequenceNumber: json['sequenceNumber'] as int,
  );
}

class ErrorMessage extends GameMessage {
  @override
  final MessageType type = MessageType.error;
  
  final String code;
  final String message;
  
  ErrorMessage({required this.code, required this.message});
  
  @override
  Map<String, dynamic> toJson() => {
    'code': code,
    'message': message,
  };
  
  factory ErrorMessage.fromJson(Map<String, dynamic> json) => ErrorMessage(
    code: json['code'] as String,
    message: json['message'] as String,
  );
}

class PlayerJoinedMessage extends GameMessage {
  @override
  final MessageType type = MessageType.playerJoined;
  
  final String playerId;
  final String displayName;
  final int playerCount;
  
  PlayerJoinedMessage({
    required this.playerId,
    required this.displayName,
    required this.playerCount,
  });
  
  @override
  Map<String, dynamic> toJson() => {
    'playerId': playerId,
    'displayName': displayName,
    'playerCount': playerCount,
  };
  
  factory PlayerJoinedMessage.fromJson(Map<String, dynamic> json) => PlayerJoinedMessage(
    playerId: json['playerId'] as String,
    displayName: json['displayName'] as String,
    playerCount: json['playerCount'] as int,
  );
}

class PlayerLeftMessage extends GameMessage {
  @override
  final MessageType type = MessageType.playerLeft;
  
  final String playerId;
  final int playerCount;
  
  PlayerLeftMessage({required this.playerId, required this.playerCount});
  
  @override
  Map<String, dynamic> toJson() => {
    'playerId': playerId,
    'playerCount': playerCount,
  };
  
  factory PlayerLeftMessage.fromJson(Map<String, dynamic> json) => PlayerLeftMessage(
    playerId: json['playerId'] as String,
    playerCount: json['playerCount'] as int,
  );
}

class PlayerReadyMessage extends GameMessage {
  @override
  final MessageType type = MessageType.playerReady;
  
  final String playerId;
  final bool isReady;
  
  PlayerReadyMessage({required this.playerId, required this.isReady});
  
  @override
  Map<String, dynamic> toJson() => {
    'playerId': playerId,
    'isReady': isReady,
  };
  
  factory PlayerReadyMessage.fromJson(Map<String, dynamic> json) => PlayerReadyMessage(
    playerId: json['playerId'] as String,
    isReady: json['isReady'] as bool,
  );
}

class GameStartMessage extends GameMessage {
  @override
  final MessageType type = MessageType.gameStart;
  
  final GameState gameState;
  
  GameStartMessage({required this.gameState});
  
  @override
  Map<String, dynamic> toJson() => {
    'gameState': gameState.toJson(),
  };
  
  factory GameStartMessage.fromJson(Map<String, dynamic> json) => GameStartMessage(
    gameState: GameState.fromJson(json['gameState'] as Map<String, dynamic>),
  );
}

class MoveAcceptedMessage extends GameMessage {
  @override
  final MessageType type = MessageType.moveAccepted;
  
  final int sequenceNumber;
  final String playerId;
  final Move move;
  
  MoveAcceptedMessage({
    required this.sequenceNumber,
    required this.playerId,
    required this.move,
  });
  
  @override
  Map<String, dynamic> toJson() => {
    'sequenceNumber': sequenceNumber,
    'playerId': playerId,
    'move': move.toJson(),
  };
  
  factory MoveAcceptedMessage.fromJson(Map<String, dynamic> json) => MoveAcceptedMessage(
    sequenceNumber: json['sequenceNumber'] as int,
    playerId: json['playerId'] as String,
    move: Move.fromJson(json['move'] as Map<String, dynamic>),
  );
}

class MoveRejectedMessage extends GameMessage {
  @override
  final MessageType type = MessageType.moveRejected;
  
  final int sequenceNumber;
  final String reason;
  
  MoveRejectedMessage({required this.sequenceNumber, required this.reason});
  
  @override
  Map<String, dynamic> toJson() => {
    'sequenceNumber': sequenceNumber,
    'reason': reason,
  };
  
  factory MoveRejectedMessage.fromJson(Map<String, dynamic> json) => MoveRejectedMessage(
    sequenceNumber: json['sequenceNumber'] as int,
    reason: json['reason'] as String,
  );
}

class StateSnapshotMessage extends GameMessage {
  @override
  final MessageType type = MessageType.stateSnapshot;
  
  final GameState gameState;
  
  StateSnapshotMessage({required this.gameState});
  
  @override
  Map<String, dynamic> toJson() => {
    'gameState': gameState.toJson(),
  };
  
  factory StateSnapshotMessage.fromJson(Map<String, dynamic> json) => StateSnapshotMessage(
    gameState: GameState.fromJson(json['gameState'] as Map<String, dynamic>),
  );
}

class RoundEndMessage extends GameMessage {
  @override
  final MessageType type = MessageType.roundEnd;
  
  final String winnerId;
  final int roundNumber;
  final Map<String, RoundScore> scores;
  
  RoundEndMessage({
    required this.winnerId,
    required this.roundNumber,
    required this.scores,
  });
  
  @override
  Map<String, dynamic> toJson() => {
    'winnerId': winnerId,
    'roundNumber': roundNumber,
    'scores': scores.map((k, v) => MapEntry(k, v.toJson())),
  };
  
  factory RoundEndMessage.fromJson(Map<String, dynamic> json) => RoundEndMessage(
    winnerId: json['winnerId'] as String,
    roundNumber: json['roundNumber'] as int,
    scores: (json['scores'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, RoundScore.fromJson(v)),
    ),
  );
}

class MatchEndMessage extends GameMessage {
  @override
  final MessageType type = MessageType.matchEnd;
  
  final List<String> winnerIds;
  final Map<String, int> finalScores;
  
  MatchEndMessage({required this.winnerIds, required this.finalScores});
  
  @override
  Map<String, dynamic> toJson() => {
    'winnerIds': winnerIds,
    'finalScores': finalScores,
  };
  
  factory MatchEndMessage.fromJson(Map<String, dynamic> json) => MatchEndMessage(
    winnerIds: (json['winnerIds'] as List).cast<String>(),
    finalScores: (json['finalScores'] as Map<String, dynamic>).cast<String, int>(),
  );
}

class PingMessage extends GameMessage {
  @override
  final MessageType type = MessageType.ping;
  
  @override
  Map<String, dynamic> toJson() => {};
}

class PongMessage extends GameMessage {
  @override
  final MessageType type = MessageType.pong;
  
  @override
  Map<String, dynamic> toJson() => {};
}

class RequestStateMessage extends GameMessage {
  @override
  final MessageType type = MessageType.requestState;
  
  final String matchId;
  final String playerId;
  
  RequestStateMessage({required this.matchId, required this.playerId});
  
  @override
  Map<String, dynamic> toJson() => {
    'matchId': matchId,
    'playerId': playerId,
  };
  
  factory RequestStateMessage.fromJson(Map<String, dynamic> json) => RequestStateMessage(
    matchId: json['matchId'] as String,
    playerId: json['playerId'] as String,
  );
}
