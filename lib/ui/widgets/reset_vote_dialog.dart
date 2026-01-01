import 'package:flutter/material.dart';
import '../theme/game_theme.dart';

/// Pop-up dialog shown to other players when someone initiates a reset vote
class ResetVoteDialog extends StatelessWidget {
  final String initiatorName;
  final VoidCallback onAgree;
  final VoidCallback onDecline;
  final bool hasVoted;

  const ResetVoteDialog({
    super.key,
    required this.initiatorName,
    required this.onAgree,
    required this.onDecline,
    this.hasVoted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              GameTheme.surface.withValues(alpha: 0.95),
              GameTheme.background.withValues(alpha: 0.95),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: GameTheme.primary.withValues(alpha: 0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: GameTheme.primary.withValues(alpha: 0.2),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: GameTheme.warning.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.refresh,
                color: GameTheme.warning,
                size: 36,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Title
            Text(
              'Reset Vote',
              style: TextStyle(
                color: GameTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Message
            Text(
              '$initiatorName wants to reset all cards!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: GameTheme.textSecondary,
                fontSize: 16,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Subtitle
            Text(
              'Do you agree to shuffle all stock & waste piles?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: GameTheme.textSecondary.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Buttons
            if (hasVoted)
              // Already voted - show confirmation
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: GameTheme.success.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, color: GameTheme.success, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'You voted to agree',
                      style: TextStyle(
                        color: GameTheme.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else
              Row(
                children: [
                  // Decline
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onDecline,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: GameTheme.error.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Decline',
                        style: TextStyle(
                          color: GameTheme.error,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Agree
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onAgree,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GameTheme.success,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Agree',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Shows the reset vote dialog and returns true if agreed, false if declined
Future<bool?> showResetVoteDialog(
  BuildContext context, {
  required String initiatorName,
  required VoidCallback onAgree,
  required VoidCallback onDecline,
  bool hasVoted = false,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false, // Must choose
    builder: (context) => ResetVoteDialog(
      initiatorName: initiatorName,
      onAgree: () {
        onAgree();
        Navigator.of(context).pop(true);
      },
      onDecline: () {
        onDecline();
        Navigator.of(context).pop(false);
      },
      hasVoted: hasVoted,
    ),
  );
}
