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
          width: 75,  // Increased from 60
          height: 70, // Increased from 55
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Nertz Pile (Card) - Shifted Right and Top
              Positioned(
                right: 4,
                top: 0,
                child: Container(
                  width: 44, // Increased from 35 (+~25%)
                  height: 62, // Increased from 50 (+~24%)
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
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
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: GameTheme.primary, // Purple circle
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                        ],
                      ),
                      child: Text(
                        '${player.nertzPile.remaining}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
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
                   width: 38, // Increased from 32
                   height: 38, // Increased from 32
                   decoration: BoxDecoration(
                     shape: BoxShape.circle,
                     border: Border.all(
                       color: player.playerColor != null 
                          ? Color(player.playerColor!) 
                          : Colors.white, 
                       width: 2
                     ),
                     color: GameTheme.surface,
                     boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                     ],
                   ),
                   child: ClipOval(
                     child: _buildAvatar(player),
                   ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(PlayerState player) {
    if (player.avatarUrl == null || player.avatarUrl!.isEmpty) {
      return Center(child: Text(player.displayName.isNotEmpty ? player.displayName[0].toUpperCase() : '?', style: const TextStyle(color: GameTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)));
    }

    // Check if it's a local asset (bots often use assets)
    if (player.avatarUrl!.startsWith('assets/') || !player.avatarUrl!.startsWith('http')) {
       return Image.asset(
         player.avatarUrl!,
         fit: BoxFit.cover,
         errorBuilder: (context, error, stackTrace) {
            return Center(child: Text(player.displayName.isNotEmpty ? player.displayName[0].toUpperCase() : '?', style: const TextStyle(color: GameTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)));
         },
       );
    }

    return Image.network(
      player.avatarUrl!,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
         return Center(child: Text(player.displayName.isNotEmpty ? player.displayName[0].toUpperCase() : '?', style: const TextStyle(color: GameTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)));
      },
    );
  }
}
