import 'package:flutter/material.dart';

/// iOS 26 style smooth animations and transitions
class AppAnimations {
  // Animation durations
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);

  // Curves
  static const Curve easeInOut = Curves.easeInOut;
  static const Curve easeOut = Curves.easeOut;
  static const Curve spring = Curves.elasticOut;
  static const Curve smooth = Curves.easeInOutCubic;

  /// Smooth page route transition (iOS-style slide)
  static PageRouteBuilder<T> createRoute<T>(Widget page, {
    RouteSettings? settings,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: normal,
      reverseTransitionDuration: fast,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Slide from right with fade
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        final slideTween = Tween(begin: begin, end: end);
        final slideAnimation = animation.drive(
          slideTween.chain(CurveTween(curve: smooth)),
        );

        final fadeTween = Tween<double>(begin: 0.0, end: 1.0);
        final fadeAnimation = animation.drive(
          fadeTween.chain(CurveTween(curve: easeOut)),
        );

        return SlideTransition(
          position: slideAnimation,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: child,
          ),
        );
      },
    );
  }

  /// Fade-in page transition
  static PageRouteBuilder<T> fadeRoute<T>(Widget page, {
    RouteSettings? settings,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: normal,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation.drive(
            Tween<double>(begin: 0.0, end: 1.0).chain(
              CurveTween(curve: easeInOut),
            ),
          ),
          child: child,
        );
      },
    );
  }

  /// Scale + fade transition (dialog-like)
  static PageRouteBuilder<T> scaleRoute<T>(Widget page, {
    RouteSettings? settings,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: normal,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final scaleTween = Tween<double>(begin: 0.9, end: 1.0);
        final scaleAnimation = animation.drive(
          scaleTween.chain(CurveTween(curve: easeOut)),
        );

        final fadeTween = Tween<double>(begin: 0.0, end: 1.0);
        final fadeAnimation = animation.drive(
          fadeTween.chain(CurveTween(curve: easeOut)),
        );

        return ScaleTransition(
          scale: scaleAnimation,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: child,
          ),
        );
      },
    );
  }

  /// Animated container wrapper with smooth transitions
  static Widget animatedContainer({
    required Widget child,
    required Duration duration,
    Curve curve = easeInOut,
    EdgeInsets? padding,
    Decoration? decoration,
  }) {
    return AnimatedContainer(
      duration: duration,
      curve: curve,
      padding: padding,
      decoration: decoration,
      child: child,
    );
  }

  /// Shimmer loading animation
  static Widget shimmer({
    required Widget child,
    bool isLoading = true,
    Duration duration = slow,
  }) {
    if (!isLoading) return child;

    return AnimatedOpacity(
      opacity: isLoading ? 0.3 : 1.0,
      duration: duration,
      curve: easeInOut,
      child: child,
    );
  }

  /// Smooth scale animation on tap (button press effect)
  static Widget pressableScale({
    required Widget child,
    required VoidCallback onPressed,
    double scale = 0.95,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 1.0, end: 1.0),
      duration: fast,
      curve: easeOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: GestureDetector(
        onTapDown: (_) {},
        onTapUp: (_) => onPressed(),
        onTapCancel: () {},
        child: child,
      ),
    );
  }

  /// Slide-in animation for cards and list items
  static Widget slideIn({
    required Widget child,
    required int index,
    Duration delay = const Duration(milliseconds: 50),
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: normal + (delay * index),
      curve: smooth,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  /// Hero animation wrapper for shared element transitions
  static Widget hero({
    required String tag,
    required Widget child,
  }) {
    return Hero(
      tag: tag,
      child: Material(
        type: MaterialType.transparency,
        child: child,
      ),
    );
  }
}
