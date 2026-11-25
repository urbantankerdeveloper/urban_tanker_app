import 'package:flutter/material.dart';

/// Routes horizontal swipes to adjacent screens or tabs.
class SwipeNavigationArea extends StatefulWidget {
  const SwipeNavigationArea({
    required this.child,
    this.onSwipeLeft,
    this.onSwipeRight,
    super.key,
  });

  final Widget child;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;

  @override
  State<SwipeNavigationArea> createState() => _SwipeNavigationAreaState();
}

class _SwipeNavigationAreaState extends State<SwipeNavigationArea> {
  static const _distanceThreshold = 48.0;
  static const _velocityThreshold = 600.0;

  double _dragDistance = 0;

  void _handleDragEnd(
    DragEndDetails details, {
    required VoidCallback? onSwipeLeft,
    required VoidCallback? onSwipeRight,
  }) {
    final velocity = details.primaryVelocity ?? 0;
    final isLeftSwipe = _dragDistance <= -_distanceThreshold ||
        (_dragDistance.abs() < _distanceThreshold &&
            velocity <= -_velocityThreshold);
    final isRightSwipe = _dragDistance >= _distanceThreshold ||
        (_dragDistance.abs() < _distanceThreshold &&
            velocity >= _velocityThreshold);

    if (isLeftSwipe) {
      onSwipeLeft?.call();
    } else if (isRightSwipe) {
      onSwipeRight?.call();
    }
    _dragDistance = 0;
  }

  @override
  Widget build(BuildContext context) {
    final parent = _SwipeNavigationScope.maybeOf(context);
    final onSwipeLeft = widget.onSwipeLeft ?? parent?.onSwipeLeft;
    final onSwipeRight = widget.onSwipeRight ?? parent?.onSwipeRight;
    final enabled = onSwipeLeft != null || onSwipeRight != null;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: enabled ? (_) => _dragDistance = 0 : null,
      onHorizontalDragUpdate:
          enabled ? (details) => _dragDistance += details.delta.dx : null,
      onHorizontalDragEnd: enabled
          ? (details) => _handleDragEnd(
                details,
                onSwipeLeft: onSwipeLeft,
                onSwipeRight: onSwipeRight,
              )
          : null,
      child: _SwipeNavigationScope(
        onSwipeLeft: onSwipeLeft,
        onSwipeRight: onSwipeRight,
        child: widget.child,
      ),
    );
  }
}

class _SwipeNavigationScope extends InheritedWidget {
  const _SwipeNavigationScope({
    required this.onSwipeLeft,
    required this.onSwipeRight,
    required super.child,
  });

  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;

  static _SwipeNavigationScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SwipeNavigationScope>();

  @override
  bool updateShouldNotify(_SwipeNavigationScope oldWidget) =>
      onSwipeLeft != oldWidget.onSwipeLeft ||
      onSwipeRight != oldWidget.onSwipeRight;
}
