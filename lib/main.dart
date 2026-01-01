/// Main entry point for Nertz Royale

library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'services/supabase_service.dart';
import 'services/audio_service.dart';
import 'state/economy_provider.dart';
import 'ui/theme/game_theme.dart';
import 'ui/screens/splash_screen.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await SupabaseService.initialize();
  } catch (e) {
    debugPrint('Supabase init failed: $e. Check config.dart.');
  }

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

class NertzRoyaleApp extends ConsumerWidget {
  const NertzRoyaleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen for music changes and update player
    ref.listen(selectedMusicAssetProvider, (previous, next) {
      if (next.hasValue && next.value != null) {
        AudioService().startBackgroundMusic(path: next.value!);
      }
    });

    return MaterialApp(
      title: 'Nertz Royale',
      debugShowCheckedModeBanner: false,
      theme: GameTheme.buildTheme(),
      home: const SplashScreen(), // Start with video splash
    );
  }
}
