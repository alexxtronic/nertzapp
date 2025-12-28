/// Playing card widget for Nertz Royale

library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/card.dart';
import '../theme/game_theme.dart';

/// A single playing card widget
class PlayingCardWidget extends StatefulWidget {
  final PlayingCard card;
  final bool faceUp;
  final bool isDraggable;
  final bool isHighlighted;
  final bool showHint;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final CardStyle style;
  
  const PlayingCardWidget({
    super.key,
    required this.card,
    this.faceUp = true,
    this.isDraggable = true,
    this.isHighlighted = false,
    this.showHint = false,
    this.onTap,
    this.onDoubleTap,
    this.style = CardStyle.normal,
  });

  @override
  State<PlayingCardWidget> createState() => _PlayingCardWidgetState();
}

class _PlayingCardWidgetState extends State<PlayingCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  
  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: GameTheme.cardFlipDuration,
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
  }
  
  @override
  void didUpdateWidget(PlayingCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.faceUp != oldWidget.faceUp) {
      _flipCard();
    }
  }
  
  void _flipCard() {
    if (widget.faceUp) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
  }
  
  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (widget.onTap != null) {
          HapticFeedback.lightImpact();
          widget.onTap!();
        }
      },
      onDoubleTap: () {
        if (widget.onDoubleTap != null) {
          HapticFeedback.mediumImpact();
          widget.onDoubleTap!();
        }
      },
      child: AnimatedBuilder(
        animation: _flipAnimation,
        builder: (context, child) {
          final angle = _flipAnimation.value * 3.14159;
          final showingFront = angle < 1.5708;
          
          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            alignment: Alignment.center,
            child: showingFront
                ? _buildCardFace(true)
                : Transform(
                    transform: Matrix4.identity()..rotateY(3.14159),
                    alignment: Alignment.center,
                    child: _buildCardFace(false),
                  ),
          );
        },
      ),
    );
  }
  
  Widget _buildCardFace(bool isFront) {
    return AnimatedContainer(
      duration: GameTheme.cardHighlightDuration,
      width: GameTheme.cardWidth,
      height: GameTheme.cardHeight,
      decoration: BoxDecoration(
        color: isFront ? GameTheme.cardBackground : GameTheme.primary,
        borderRadius: BorderRadius.circular(GameTheme.cardRadius),
        border: Border.all(
          color: widget.isHighlighted
              ? GameTheme.accent
              : widget.showHint
                  ? GameTheme.success
                  : GameTheme.cardBorder,
          width: widget.isHighlighted || widget.showHint ? 2 : 1,
        ),
        boxShadow: widget.isHighlighted
            ? GameTheme.cardHoverShadow
            : GameTheme.cardShadow,
      ),
      child: isFront ? _buildCardContent() : _buildCardBack(),
    );
  }
  
  Widget _buildCardContent() {
    final color = widget.card.color == CardColor.red
        ? widget.style.redColor
        : widget.style.blackColor;
    
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCorner(color),
          Expanded(
            child: Center(
              child: Text(
                widget.card.suit.symbol,
                style: TextStyle(
                  fontSize: 32,
                  color: color,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Transform.rotate(
              angle: 3.14159,
              child: _buildCorner(color),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCorner(Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.card.rank.symbol,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
            height: 1,
          ),
        ),
        Text(
          widget.style.useShapes
              ? widget.card.suit.accessibilityShape
              : widget.card.suit.symbol,
          style: TextStyle(
            fontSize: 10,
            color: color,
            height: 1,
          ),
        ),
      ],
    );
  }
  
  Widget _buildCardBack() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(GameTheme.cardRadius - 1),
        gradient: GameTheme.primaryGradient,
      ),
      child: Center(
        child: Container(
          width: GameTheme.cardWidth - 16,
          height: GameTheme.cardHeight - 16,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white30, width: 2),
          ),
          child: Center(
            child: Text(
              'N',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Draggable card wrapper
class DraggableCard extends StatefulWidget {
  final PlayingCard card;
  final bool faceUp;
  final bool canDrag;
  final CardStyle style;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final Function(PlayingCard)? onDragStart;
  final Function(PlayingCard)? onDragEnd;
  
  const DraggableCard({
    super.key,
    required this.card,
    this.faceUp = true,
    this.canDrag = true,
    this.style = CardStyle.normal,
    this.onTap,
    this.onDoubleTap,
    this.onDragStart,
    this.onDragEnd,
  });

  @override
  State<DraggableCard> createState() => _DraggableCardState();
}

class _DraggableCardState extends State<DraggableCard> {
  bool _isDragging = false;
  
  @override
  Widget build(BuildContext context) {
    if (!widget.canDrag || !widget.faceUp) {
      return PlayingCardWidget(
        card: widget.card,
        faceUp: widget.faceUp,
        isDraggable: false,
        style: widget.style,
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
      );
    }
    
    return Draggable<PlayingCard>(
      data: widget.card,
      onDragStarted: () {
        setState(() => _isDragging = true);
        HapticFeedback.selectionClick();
        widget.onDragStart?.call(widget.card);
      },
      onDragEnd: (_) {
        setState(() => _isDragging = false);
        widget.onDragEnd?.call(widget.card);
      },
      feedback: Material(
        color: Colors.transparent,
        child: Transform.scale(
          scale: 1.1,
          child: Container(
            decoration: BoxDecoration(
              boxShadow: GameTheme.cardDraggingShadow,
              borderRadius: BorderRadius.circular(GameTheme.cardRadius),
            ),
            child: PlayingCardWidget(
              card: widget.card,
              faceUp: true,
              isHighlighted: true,
              style: widget.style,
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: PlayingCardWidget(
          card: widget.card,
          faceUp: true,
          style: widget.style,
        ),
      ),
      child: AnimatedScale(
        scale: _isDragging ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: PlayingCardWidget(
          card: widget.card,
          faceUp: widget.faceUp,
          style: widget.style,
          onTap: widget.onTap,
          onDoubleTap: widget.onDoubleTap,
        ),
      ),
    );
  }
}

/// Empty card slot placeholder
class CardSlot extends StatelessWidget {
  final String? label;
  final bool isHighlighted;
  final bool isValidTarget;
  final VoidCallback? onTap;
  
  const CardSlot({
    super.key,
    this.label,
    this.isHighlighted = false,
    this.isValidTarget = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: GameTheme.cardHighlightDuration,
        width: GameTheme.cardWidth,
        height: GameTheme.cardHeight,
        decoration: BoxDecoration(
          color: isValidTarget
              ? GameTheme.success.withValues(alpha: 0.2)
              : GameTheme.surfaceLight.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(GameTheme.cardRadius),
          border: Border.all(
            color: isValidTarget
                ? GameTheme.success
                : isHighlighted
                    ? GameTheme.accent
                    : GameTheme.surfaceLight,
            width: isValidTarget || isHighlighted ? 2 : 1,
          ),
        ),
        child: label != null
            ? Center(
                child: Text(
                  label!,
                  style: TextStyle(
                    color: GameTheme.textSecondary.withValues(alpha: 0.5),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
