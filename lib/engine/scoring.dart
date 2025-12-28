/// Scoring system for Nertz Royale

library;

import '../models/game_state.dart';

/// Scoring calculations
class Scoring {
  static int calculateRoundScore(int cardsInCenter, int cardsInNertz) {
    return cardsInCenter - (cardsInNertz * 2);
  }

  static Map<String, RoundScore> calculateAllScores(GameState gameState) {
    final scores = <String, RoundScore>{};

    for (final player in gameState.players.values) {
      final cardsInCenter = gameState.countPlayerCardsInCenter(player.id);
      final cardsInNertz = player.nertzPile.remaining;
      final roundScore = calculateRoundScore(cardsInCenter, cardsInNertz);

      scores[player.id] = RoundScore(
        playerId: player.id,
        playerName: player.displayName,
        cardsPlayedToCenter: cardsInCenter,
        cardsRemainingInNertz: cardsInNertz,
        centerPoints: cardsInCenter,
        nertzPenalty: cardsInNertz * 2,
        roundScore: roundScore,
        previousTotal: player.scoreTotal - roundScore,
        newTotal: player.scoreTotal,
      );
    }

    return scores;
  }

  static String formatScoreSummary(RoundScore score) {
    final sign = score.roundScore >= 0 ? '+' : '';
    return '${score.playerName}: $sign${score.roundScore} '
           '(${score.cardsPlayedToCenter} played, '
           '-${score.nertzPenalty} penalty) = ${score.newTotal} total';
  }
}

class RoundScore {
  final String playerId;
  final String playerName;
  final int cardsPlayedToCenter;
  final int cardsRemainingInNertz;
  final int centerPoints;
  final int nertzPenalty;
  final int roundScore;
  final int previousTotal;
  final int newTotal;

  RoundScore({
    required this.playerId,
    required this.playerName,
    required this.cardsPlayedToCenter,
    required this.cardsRemainingInNertz,
    required this.centerPoints,
    required this.nertzPenalty,
    required this.roundScore,
    required this.previousTotal,
    required this.newTotal,
  });

  bool get isNegative => roundScore < 0;
  bool get reachedTarget => newTotal >= 100;

  Map<String, dynamic> toJson() => {
    'playerId': playerId,
    'playerName': playerName,
    'cardsPlayedToCenter': cardsPlayedToCenter,
    'cardsRemainingInNertz': cardsRemainingInNertz,
    'centerPoints': centerPoints,
    'nertzPenalty': nertzPenalty,
    'roundScore': roundScore,
    'previousTotal': previousTotal,
    'newTotal': newTotal,
  };

  factory RoundScore.fromJson(Map<String, dynamic> json) => RoundScore(
    playerId: json['playerId'] as String,
    playerName: json['playerName'] as String,
    cardsPlayedToCenter: json['cardsPlayedToCenter'] as int,
    cardsRemainingInNertz: json['cardsRemainingInNertz'] as int,
    centerPoints: json['centerPoints'] as int,
    nertzPenalty: json['nertzPenalty'] as int,
    roundScore: json['roundScore'] as int,
    previousTotal: json['previousTotal'] as int,
    newTotal: json['newTotal'] as int,
  );
}
