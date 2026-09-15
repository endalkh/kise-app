/// A one-shot entrance: fade in while drifting up a little.
///
/// Dashboard sections reveal in sequence so the screen feels assembled rather than dumped. The
/// animation is finite, so widget tests that `pumpAndSettle` complete, and the child is in the tree
/// from the first frame, so finders see it before it is fully visible.
library;

import 'package:flutter/material.dart';

class Reveal extends StatelessWidget {
  const Reveal({super.key, required this.child, this.order = 0});

  final Widget child;

  /// Position in the sequence. Each step starts a little after the one before.
  final int order;

  static const Duration _step = Duration(milliseconds: 90);
  static const Duration _duration = Duration(milliseconds: 480);

  @override
  Widget build(BuildContext context) {
    final delay = _step * order;
    final total = _duration + delay;
    final begin = delay.inMilliseconds / total.inMilliseconds;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(begin, 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 20), child: child),
      ),
    );
  }
}
