import 'package:flutter/material.dart';
import 'package:nertz_royale/models/player_state.dart';
import 'package:nertz_royale/ui/theme/game_theme.dart';
import 'package:nertz_royale/services/economy_service.dart';

class OpponentBoard extends StatelessWidget {
  final PlayerState player;

  const OpponentBoard({required this.player, super.key});

  @override
  Widget build(BuildContext context) {
    // Determine card back asset
    final cardBackAsset = player.selectedCardBack != null
        ? EconomyService.getCardBackAssetPath(player.selectedCardBack!)
        : 'assets/card_back.png'; // Default

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Name on top, very small
        Text(
          player.displayName,
          style: TextStyle(
            color: GameTheme.textSecondary.withValues(alpha: 0.8),
            fontSize: 9, 
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        const SizedBox(height: 2),
        // Overlapping Stack
        SizedBox(
          width: 60, 
          height: 55, 
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Nertz Pile (Card) - Shifted Right and Top
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 35,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(1, 1)),
                    ],
                    image: DecorationImage(
                      image: AssetImage(cardBackAsset),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${player.nertzPile.remaining}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Avatar - Bottom Left, overlapping
              Positioned(
                left: 0,
                bottom: 0,
                child: Container(
                   width: 32,
                   height: 32,
                   decoration: BoxDecoration(
                     shape: BoxShape.circle,
                     border: Border.all(
                       color: player.playerColor != null 
                          ? Color(player.playerColor!) 
                          : Colors.white, 
                       width: 2
                     ),
                     image: player.avatarUrl != null 
                        ? DecorationImage(image: NetworkImage(player.avatarUrl!), fit: BoxFit.cover)
                        : null,
                     color: GameTheme.surface,
                     boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                     ],
                   ),
                   child: player.avatarUrl == null 
                     ? Center(child: Text(player.displayName.isNotEmpty ? player.displayName[0].toUpperCase() : '?', style: const TextStyle(color: GameTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)))
                     : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
