import 'package:flutter/material.dart';

/// One rhythm for every page in the app: quick enough to feel instant,
/// long enough for the fade-through to read as a premium transition.
const Duration premiumTransitionDuration = Duration(milliseconds: 420);
const Duration premiumReverseTransitionDuration = Duration(milliseconds: 300);

/// Fade-through with a small lift and a 98.5% → 100% settle.
///
/// Used by every route so pushing a screen never hard-cuts, and so a screen
/// never fades over an empty background (the outgoing page stays under it).
Widget premiumPageTransition(
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child, {
  Offset begin = const Offset(0, 0.03),
}) {
  final curved = CurvedAnimation(
    parent: animation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  return FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
    child: SlideTransition(
      position: Tween<Offset>(begin: begin, end: Offset.zero).animate(curved),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.985, end: 1).animate(curved),
        child: child,
      ),
    ),
  );
}

/// Imperative replacement for `MaterialPageRoute` with the same feel.
Route<T> premiumRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: premiumTransitionDuration,
    reverseTransitionDuration: premiumReverseTransitionDuration,
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, animation, secondaryAnimation, child) =>
        premiumPageTransition(animation, secondaryAnimation, child),
  );
}

/// Applies [premiumPageTransition] to every theme-driven Material push, so
/// screens opened with `Navigator.push` match the go_router pages.
class PremiumPageTransitionsBuilder extends PageTransitionsBuilder {
  const PremiumPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return premiumPageTransition(animation, secondaryAnimation, child);
  }
}
