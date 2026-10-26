import 'package:flutter/material.dart';

/// Shared, short-duration motion for operational screens.
/// Explicitly respects the operating system's Reduce Motion setting.
abstract final class FactoryMotion {
  static const quick = Duration(milliseconds: 140);
  static const standard = Duration(milliseconds: 220);
  static const navigation = Duration(milliseconds: 260);

  static bool reduceMotion(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  static Duration duration(BuildContext context, Duration preferred) =>
      reduceMotion(context) ? Duration.zero : preferred;

  static Route<T> page<T>(BuildContext context, Widget child) =>
      PageRouteBuilder<T>(
        transitionDuration: duration(context, navigation),
        reverseTransitionDuration: duration(context, standard),
        pageBuilder: (_, _, _) => child,
        transitionsBuilder: (routeContext, animation, secondary, page) {
          if (reduceMotion(routeContext)) return page;
          final eased = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: eased,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.06, 0.015),
                end: Offset.zero,
              ).animate(eased),
              child: page,
            ),
          );
        },
      );
}

/// Gentle one-time entrance, not an infinite or distracting loop.
class FactoryReveal extends StatelessWidget {
  const FactoryReveal({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: FactoryMotion.duration(context, FactoryMotion.navigation),
        curve: Curves.easeOutCubic,
        builder: (context, progress, child) => Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - progress)),
            child: child,
          ),
        ),
        child: child,
      );
}

/// Tactile card feedback without animation packages or custom gesture handling.
class FactoryPressCard extends StatefulWidget {
  const FactoryPressCard({
    required this.child,
    required this.onTap,
    super.key,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  State<FactoryPressCard> createState() => _FactoryPressCardState();
}

class _FactoryPressCardState extends State<FactoryPressCard> {
  bool highlighted = false;

  @override
  Widget build(BuildContext context) => AnimatedScale(
        scale: highlighted ? 0.985 : 1,
        duration: FactoryMotion.duration(context, FactoryMotion.quick),
        curve: Curves.easeOut,
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE0E8F1)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: (value) {
              if (mounted) setState(() => highlighted = value);
            },
            child: Semantics(
              button: true,
              label: widget.semanticLabel,
              child: widget.child,
            ),
          ),
        ),
      );
}
