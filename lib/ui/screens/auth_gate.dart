import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'main_navigation_screen.dart';

/// Routes between Login and Lobby based on authentication state
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // You could return a loading screen here, 
          // but usually Supabase is fast enough or has cached session
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.data?.session;

        // If we have a valid session, go to Lobby
        if (session != null) {
          return const MainNavigationScreen();
        }

        // Otherwise go to Login
        return const LoginScreen();
      },
    );
  }
}
