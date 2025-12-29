/// Currency display widget for Nertz Royale
/// Shows coins and gems in the app header/UI

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/economy_provider.dart';
import '../theme/game_theme.dart';

class CurrencyDisplay extends ConsumerWidget {
  final bool compact;
  
  const CurrencyDisplay({
    super.key,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(balanceProvider);
    
    return balanceAsync.when(
      data: (balance) {
        if (balance == null) return const SizedBox.shrink();
        
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CurrencyChip(
              icon: '🪙',
              value: balance.coins,
              color: const Color(0xFFFFD700), // Gold
              compact: compact,
            ),
            const SizedBox(width: 8),
            _CurrencyChip(
              icon: '💎',
              value: balance.gems,
              color: const Color(0xFF00CED1), // Cyan
              compact: compact,
            ),
          ],
        );
      },
      loading: () => const SizedBox(
        width: 80,
        height: 2,
        child: LinearProgressIndicator(),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _CurrencyChip extends StatelessWidget {
  final String icon;
  final int value;
  final Color color;
  final bool compact;

  const _CurrencyChip({
    required this.icon,
    required this.value,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            icon,
            style: TextStyle(fontSize: compact ? 14 : 16),
          ),
          const SizedBox(width: 4),
          Text(
            _formatNumber(value),
            style: TextStyle(
              color: GameTheme.textPrimary,
              fontSize: compact ? 12 : 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatNumber(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toString();
  }
}

/// Animated coin/gem reward popup
class CurrencyRewardPopup extends StatefulWidget {
  final int amount;
  final bool isGems;
  final VoidCallback? onComplete;

  const CurrencyRewardPopup({
    super.key,
    required this.amount,
    this.isGems = false,
    this.onComplete,
  });

  @override
  State<CurrencyRewardPopup> createState() => _CurrencyRewardPopupState();
}

class _CurrencyRewardPopupState extends State<CurrencyRewardPopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.2).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.2, end: 1.0),
        weight: 40,
      ),
    ]).animate(_controller);
    
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.forward().then((_) => widget.onComplete?.call());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                gradient: widget.isGems
                    ? const LinearGradient(
                        colors: [Color(0xFF00CED1), Color(0xFF20B2AA)],
                      )
                    : const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                      ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: (widget.isGems ? const Color(0xFF00CED1) : const Color(0xFFFFD700))
                        .withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.isGems ? '💎' : '🪙',
                    style: const TextStyle(fontSize: 28),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '+${widget.amount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(color: Colors.black26, blurRadius: 4),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
