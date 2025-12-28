/// Audio service for Nertz Royale
/// Handles sound effects for game events

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  
  final AudioPlayer _player = AudioPlayer();
  
  // Cache players for low latency overlapping sounds
  final List<AudioPlayer> _sfxPool = [];
  int _poolIndex = 0;
  static const int _poolSize = 5;

  AudioService._internal() {
    // Initialize pool
    for (int i = 0; i < _poolSize; i++) {
      _sfxPool.add(AudioPlayer());
      _sfxPool[i].setReleaseMode(ReleaseMode.stop);
    }
  }

  /// Preload common sounds
  Future<void> init() async {
    // AudioPlayers preloads automatically on web usually, but we can try to prepare
    // In a real app we might verify assets exist here
  }

  /// Play a sound effect
  Future<void> playSound(String assetPath) async {
    if (kIsWeb) {
      // Web specific handling if needed, but AudioPlayers abstracts this well
    }
    
    try {
      final player = _sfxPool[_poolIndex];
      _poolIndex = (_poolIndex + 1) % _poolSize;
      
      await player.stop(); // Stop potential previous sound
      
      // Safety check for web or missing assets
      try {
        await player.setSource(AssetSource(assetPath));
        await player.resume();
      } catch (e) {
        debugPrint('Failed to load/play sound $assetPath: $e');
        // Do not rethrow, just fail silently to prevent app crash
      }
    } catch (e) {
      debugPrint('Error accessing audio pool $assetPath: $e');
    }
  }

  /// Shuffle sound
  Future<void> playShuffle() async {
    await playSound('audio/shuffle.mp3'); 
  }

  /// Go! sound
  Future<void> playGo() async {
    await playSound('audio/go.mp3');
  }

  /// Nertz Button impact / explosion
  Future<void> playExplosion() async {
    await playSound('audio/explosion.mp3');
  }

  /// Applause for winner
  Future<void> playApplause() async {
    await playSound('audio/applause.mp3');
  }
}
