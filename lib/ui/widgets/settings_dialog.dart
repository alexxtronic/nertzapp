import 'package:flutter/material.dart';
import '../theme/game_theme.dart';
import '../../services/audio_service.dart';

/// Show settings dialog with optional leave match action
void showSettingsDialog(BuildContext context, {VoidCallback? onLeaveMatch}) {
  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 340),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  GameTheme.background,
                  GameTheme.background.withValues(alpha: 0.95),
                ],
              ),
              borderRadius: BorderRadius.circular(GameTheme.radius24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(GameTheme.spacing24),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(GameTheme.spacing12),
                        decoration: BoxDecoration(
                          gradient: GameTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(GameTheme.radius12),
                        ),
                        child: const Icon(Icons.settings, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: GameTheme.spacing16),
                      const Expanded(
                        child: Text(
                          'Settings',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: GameTheme.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: GameTheme.textSecondary),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                
                // Music toggle
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    GameTheme.spacing24, 
                    0, 
                    GameTheme.spacing24, 
                    GameTheme.spacing16,
                  ),
                  child: _buildSettingRow(
                    icon: Icons.music_note,
                    title: 'Background Music',
                    value: AudioService().musicEnabled,
                    onChanged: (value) {
                      AudioService().setMusicEnabled(value);
                      setDialogState(() {});
                    },
                  ),
                ),
                
                // Leave Match button (only shown when in-game)
                if (onLeaveMatch != null)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      GameTheme.spacing24, 
                      0, 
                      GameTheme.spacing24, 
                      GameTheme.spacing24,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context); // Close dialog first
                          _showLeaveConfirmation(context, onLeaveMatch);
                        },
                        icon: const Icon(Icons.exit_to_app),
                        label: const Text('Leave Match'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: GameTheme.error,
                          side: const BorderSide(color: GameTheme.error),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(GameTheme.radius12),
                          ),
                        ),
                      ),
                    ),
                  ),
                
                if (onLeaveMatch == null)
                  const SizedBox(height: GameTheme.spacing8),
              ],
            ),
          ),
        );
      },
    ),
  );
}

void _showLeaveConfirmation(BuildContext context, VoidCallback onLeaveMatch) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: GameTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GameTheme.radius16),
      ),
      title: const Text(
        'Leave Match?',
        style: TextStyle(color: GameTheme.textPrimary),
      ),
      content: const Text(
        'Your progress in this game will be lost.',
        style: TextStyle(color: GameTheme.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context); // Close confirmation
            onLeaveMatch();
          },
          style: TextButton.styleFrom(
            foregroundColor: GameTheme.error,
          ),
          child: const Text('LEAVE'),
        ),
      ],
    ),
  );
}

Widget _buildSettingRow({
  required IconData icon,
  required String title,
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  return Container(
    padding: const EdgeInsets.all(GameTheme.spacing16),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(GameTheme.radius16),
      border: Border.all(color: GameTheme.glassBorder),
    ),
    child: Row(
      children: [
        Icon(icon, color: GameTheme.primary, size: 24),
        const SizedBox(width: GameTheme.spacing16),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: GameTheme.textPrimary,
            ),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: GameTheme.primary,
        ),
      ],
    ),
  );
}
