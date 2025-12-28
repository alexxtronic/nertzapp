import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/game_theme.dart';
import '../../services/supabase_service.dart';
import '../../services/audio_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  // Toggle between Sign In / Sign Up
  bool _isSignUp = false;

  final SupabaseService _authService = SupabaseService();

  Future<void> _signInAnonymously() async {
    setState(() => _isLoading = true);
    try {
      await _authService.signInAnonymously();
      // Start background music after user interaction
      AudioService().startBackgroundMusic();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: GameTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_isSignUp) {
        await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
        );
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account created! Sign in to continue together.')),
          );
           // Auto login usually happens on signup depending on config, 
           // but often requires email confirmation if enabled.
           // For simplicity let's assume it logs them in or asks to confirm.
        }
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        // Start background music after user interaction
        AudioService().startBackgroundMusic();
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: GameTheme.error),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unexpected error: $e'), backgroundColor: GameTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // "Million Dollar" Aesthetic: Clean, centered, whitespace
    return Scaffold(
      backgroundColor: Colors.white, 
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Hero Logo
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: GameTheme.backgroundEnd,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: GameTheme.softShadow,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: Image.asset(
                      'assets/app_icon.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_,__,___) => const Icon(Icons.style, size: 60, color: GameTheme.primary),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 48),

              // 2. Headings
              Text(
                _isSignUp ? 'Create Account' : 'Welcome Back',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: GameTheme.textPrimary,
                  letterSpacing: -1,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _isSignUp 
                  ? 'Sign up to save your rank and stats.' 
                  : 'Enter your credentials to continue.',
                style: const TextStyle(
                  fontSize: 16,
                  color: GameTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // 3. Inputs (Clean Slate Style)
              TextField(
                controller: _emailController,
                decoration: _inputDecoration('Email Address', Icons.email_outlined),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: _inputDecoration('Password', Icons.lock_outline),
                obscureText: true,
              ),
              
              const SizedBox(height: 32),

              // 4. Primary Action
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GameTheme.primary,
                    elevation: 0, // Flat styling for modern look
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading 
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white))
                    : Text(
                        _isSignUp ? 'Create Account' : 'Sign In',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                ),
              ),
              
              const SizedBox(height: 24),

              // 5. Secondary Actions
              TextButton(
                onPressed: () {
                   setState(() {
                     _isSignUp = !_isSignUp;
                   });
                },
                child: RichText(
                  text: TextSpan(
                    text: _isSignUp ? 'Already have an account? ' : "Don't have an account? ",
                    style: const TextStyle(color: GameTheme.textSecondary),
                    children: [
                      TextSpan(
                        text: _isSignUp ? 'Sign In' : 'Sign Up',
                        style: const TextStyle(
                          color: GameTheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),

              // 6. Guest Mode
              OutlinedButton(
                onPressed: _isLoading ? null : _signInAnonymously,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: GameTheme.glassBorder),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Play as Guest', style: TextStyle(color: GameTheme.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: GameTheme.textSecondary),
      filled: true,
      fillColor: GameTheme.surfaceLight, // Very light grey
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none, // Clean look
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: GameTheme.primary, width: 2), // Highlight
      ),
      floatingLabelBehavior: FloatingLabelBehavior.auto,
    );
  }
  
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
