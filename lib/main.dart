/// Main entry point for Nertz Royale

library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'services/supabase_service.dart';
import 'services/audio_service.dart';
import 'ui/theme/game_theme.dart';
import 'ui/screens/auth_gate.dart';
import 'ui/screens/lobby_screen.dart'; // Kept if needed later, or remove if unused in main


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await SupabaseService.initialize();
  } catch (e) {
    debugPrint('Supabase init failed: $e. Check config.dart.');
  }
  
  // Start background music
  AudioService().startBackgroundMusic();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: GameTheme.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  
  runApp(
    const ProviderScope(
      child: NertzRoyaleApp(),
    ),
  );
}

class NertzRoyaleApp extends StatelessWidget {
  const NertzRoyaleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nertz Royale',
      debugShowCheckedModeBanner: false,
      theme: GameTheme.buildTheme(),
      home: const AuthGate(),
    );
  }
}
