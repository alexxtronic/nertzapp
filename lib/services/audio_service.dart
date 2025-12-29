import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  
  final AudioPlayer _player = AudioPlayer();
  
  // Dedicated background music player
  final AudioPlayer _bgMusicPlayer = AudioPlayer();
  bool _musicEnabled = true;
  
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
    
    // Configure background music player
    _bgMusicPlayer.setReleaseMode(ReleaseMode.loop);
    _bgMusicPlayer.setVolume(0.4); // Regular volume (40%)
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

  /// Start background music
  Future<void> startBackgroundMusic() async {
    if (!_musicEnabled) return;
    
    try {
      await _bgMusicPlayer.stop();
      await _bgMusicPlayer.setSource(AssetSource('audio/background.mp3'));
      await _bgMusicPlayer.resume();
      debugPrint('🎵 Background music started');
    } catch (e) {
      debugPrint('Failed to start background music: $e');
    }
  }

  /// Stop background music
  Future<void> stopBackgroundMusic() async {
    try {
      await _bgMusicPlayer.stop();
      debugPrint('🎵 Background music stopped');
    } catch (e) {
      debugPrint('Failed to stop background music: $e');
    }
  }

  /// Toggle music on/off
  Future<void> setMusicEnabled(bool enabled) async {
    _musicEnabled = enabled;
    if (enabled) {
      await startBackgroundMusic();
    } else {
      await stopBackgroundMusic();
    }
  }

  bool get musicEnabled => _musicEnabled;

  /// Shuffle sound
  Future<void> playShuffle() async {
    debugPrint('🔊 Playing shuffle sound');
    await playSound('audio/shuffle.mp3'); 
  }

  /// Countdown sound (3-2-1) - Fixed path to match actual file
  Future<void> playCountdown() async {
    debugPrint('🔊 Playing countdown sound');
    await playSound('audio/Countdown.mp3'); // Capital C
  }

  /// Go! sound
  Future<void> playGo() async {
    await playSound('audio/go.mp3');
  }

  /// Nertz Button impact / explosion
  Future<void> playExplosion() async {
    await playSound('audio/explosion.mp3');
  }

  /// Applause for overall game winner (100 points)
  Future<void> playApplause() async {
    await playSound('audio/applause.mp3');
  }

  /// Winner sound for round win
  Future<void> playWinner() async {
    debugPrint('🔊 Playing winner sound');
    await playSound('audio/winner.mp3');
  }

  /// Ping sound for center pile placement
  Future<void> playPing() async {
    await playSound('audio/ping.mp3');
  }
}
