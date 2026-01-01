import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:nertz_royale/ui/screens/auth_gate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    // Load the video asset
    _controller = VideoPlayerController.asset('assets/nertz_vid.mp4');

    try {
      await _controller.initialize();
      // Ensure the video fits the screen (cover) 
      // Note: We'll handle aspect ratio in the build method
      
      // Mute audio for splash screen? Usually better UX to start silent or let system decide.
      // Let's keep it audible if it has cool sound, user can adjust volume.
      // Or maybe mute by default? Let's leave volume on for now as it's a game.
      _controller.setVolume(1.0); 

      // Remove listener to avoid leaks or complex state logic, just use await for end?
      // Actually, listening for end is better.
      _controller.addListener(_checkVideoEnd);

      setState(() {
        _initialized = true;
      });

      await _controller.play();
    } catch (e) {
      debugPrint("Error initializing splash video: $e");
      // If video fails, skip to auth immediately
      _navigateToNext();
    }
  }

  void _checkVideoEnd() {
    if (_controller.value.isInitialized && 
        _controller.value.position >= _controller.value.duration) {
      // Video finished
      _navigateToNext();
    }
  }

  void _navigateToNext() {
    // Prevent multiple navigations
    _controller.removeListener(_checkVideoEnd);
    
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const AuthGate(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark background while loading
      body: SizedBox.expand(
        child: _initialized
            ? FittedBox(
                // cover ensures it fills the screen (zooming/cropping if needed)
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              )
            : const Center(
                // Loading indicator if valid init takes time, usually instantaneous for local assets
                child: SizedBox(), 
              ),
      ),
    );
  }
}
