import 'package:flutter/material.dart';
import '../theme/game_theme.dart';
import '../../services/audio_service.dart';

void showSettingsDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 300,
            padding: const EdgeInsets.all(24),
            decoration: GameTheme.glassDecoration,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Settings ⚙️', style: GameTheme.h2),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Background Music 🎵',
                        style: TextStyle(color: GameTheme.textPrimary)),
                    Switch(
                      value: AudioService().musicEnabled,
                      onChanged: (value) {
                        AudioService().setMusicEnabled(value);
                        setDialogState(() {}); // Update dialog
                      },
                      activeColor: GameTheme.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GameTheme.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CLOSE'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
