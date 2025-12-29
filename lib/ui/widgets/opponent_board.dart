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

    return Container(
      width: 80, // Compact width
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar
          Container(
             width: 40,
             height: 40,
             decoration: BoxDecoration(
               shape: BoxShape.circle,
               border: Border.all(color: Colors.white, width: 2),
               image: player.avatarUrl != null 
                  ? DecorationImage(image: NetworkImage(player.avatarUrl!), fit: BoxFit.cover)
                  : null,
               color: Color(player.playerColor ?? 0xFF2196F3),
             ),
             child: player.avatarUrl == null 
               ? Center(child: Text(player.displayName.isNotEmpty ? player.displayName[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
               : null,
          ),
          const SizedBox(height: 2),
          // Name
          Text(
            player.displayName,
            style: const TextStyle(
              color: GameTheme.textSecondary,
              fontSize: 10, 
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 4),
          // Nertz Pile (Back)
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 45,
                height: 65, // Scaled down card
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: const [
                    BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(1, 1)),
                  ],
                  image: DecorationImage(
                    image: AssetImage(cardBackAsset),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              // Count Badge
              Positioned(
                bottom: -6,
                right: -6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: GameTheme.accent,
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
            ],
          ),
        ],
      ),
    );
  }
}
