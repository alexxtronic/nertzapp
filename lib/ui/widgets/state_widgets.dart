import 'package:flutter/material.dart';
import '../theme/game_theme.dart';

/// Reusable empty state widget with consistent styling
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(GameTheme.spacing32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(GameTheme.spacing24),
              decoration: BoxDecoration(
                color: GameTheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: GameTheme.primary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: GameTheme.spacing24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: GameTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: GameTheme.spacing8),
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 14,
                  color: GameTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: GameTheme.spacing24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Loading state with skeleton shimmer
class LoadingState extends StatelessWidget {
  final String? message;

  const LoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: GameTheme.primary,
            strokeWidth: 3,
          ),
          if (message != null) ...[
            const SizedBox(height: GameTheme.spacing16),
            Text(
              message!,
              style: const TextStyle(
                color: GameTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Error state with retry action
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorState({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(GameTheme.spacing32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(GameTheme.spacing24),
              decoration: BoxDecoration(
                color: GameTheme.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 48,
                color: GameTheme.error.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: GameTheme.spacing24),
            const Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: GameTheme.textPrimary,
              ),
            ),
            const SizedBox(height: GameTheme.spacing8),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: GameTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: GameTheme.spacing24),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
