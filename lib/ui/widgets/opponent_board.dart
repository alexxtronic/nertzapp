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
        // Name on top, slightly larger
        Text(
          player.displayName,
          style: TextStyle(
            color: GameTheme.textSecondary.withValues(alpha: 0.8),
            fontSize: 11, 
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        const SizedBox(height: 4),
        // Overlapping Stack
        SizedBox(
          width: 94,  
          height: 88, 
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Nertz Pile (Card) - Shifted Right and Top
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 55, 
                  height: 78, 
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(1, 1)),
                    ],
                    image: DecorationImage(
                      image: AssetImage(cardBackAsset),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Nertz remaining count circle in bottom right - inside the card
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: GameTheme.primary, // Purple circle
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2)),
                            ],
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
                ),
              ),

              // Avatar - Bottom Left, overlapping
              Positioned(
                left: 0,
                bottom: 0, 
                child: Container(
                   width: 52, 
                   height: 52, 
                   decoration: BoxDecoration(
                     shape: BoxShape.circle,
                     border: Border.all(
                       color: player.playerColor != null 
                          ? Color(player.playerColor!) 
                          : Colors.white, 
                       width: 3
                     ),
                     color: GameTheme.surface,
                     boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
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
      return Container(
        color: GameTheme.surface,
        alignment: Alignment.center,
        child: Text(
          player.displayName.isNotEmpty ? player.displayName[0].toUpperCase() : '?', 
          style: const TextStyle(color: GameTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)
        ),
      );
    }

    // Check if it's a local asset
    final isLocal = player.avatarUrl!.startsWith('assets/') || !player.avatarUrl!.startsWith('http');
    
    if (isLocal) {
       return Image.asset(
         player.avatarUrl!,
         fit: BoxFit.cover,
         errorBuilder: (context, error, stackTrace) {
            debugPrint('❌ Error loading local avatar: ${player.avatarUrl}');
            return Center(child: Text(player.displayName.isNotEmpty ? player.displayName[0].toUpperCase() : '?', style: const TextStyle(color: GameTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)));
         },
       );
    }

    return Image.network(
      player.avatarUrl!,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                : null,
            strokeWidth: 2,
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
         debugPrint('❌ Error loading network avatar: ${player.avatarUrl}');
         return Center(child: Text(player.displayName.isNotEmpty ? player.displayName[0].toUpperCase() : '?', style: const TextStyle(color: GameTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)));
      },
    );
  }
}
