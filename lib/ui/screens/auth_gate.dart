import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../state/economy_provider.dart';
import 'login_screen.dart';
import 'main_navigation_screen.dart';

/// Routes between Login and Lobby based on authentication state
/// CRITICAL: Invalidates all user-specific providers on auth change
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  String? _lastUserId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.data?.session;
        final currentUserId = session?.user.id;

        // CRITICAL FIX: Invalidate all cached user data when user changes
        if (currentUserId != _lastUserId) {
          debugPrint('🔄 User changed: $_lastUserId -> $currentUserId');
          _lastUserId = currentUserId;
          
          // Schedule invalidation after this frame to avoid build-time modifications
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _invalidateAllUserProviders();
          });
        }

        // If we have a valid session, go to main navigation
        if (session != null) {
          return const MainNavigationScreen();
        }

        // Otherwise go to Login
        return const LoginScreen();
      },
    );
  }

  /// Invalidate ALL user-specific cached providers
  void _invalidateAllUserProviders() {
    debugPrint('🔄 Invalidating all user-specific providers...');
    
    // Economy
    ref.invalidate(balanceProvider);
    ref.invalidate(inventoryProvider);
    ref.invalidate(transactionHistoryProvider);
    
    // Customization
    ref.invalidate(selectedCardBackProvider);
    ref.invalidate(selectedCardBackAssetProvider);
    ref.invalidate(selectedMusicIdProvider);
    ref.invalidate(selectedMusicAssetProvider);
    ref.invalidate(selectedBackgroundIdProvider);
    ref.invalidate(selectedBackgroundAssetProvider);
    
    debugPrint('✅ All providers invalidated for new user session');
  }
}
