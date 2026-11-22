import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../../core/theme/app_theme.dart';

/// Horizontal shake driven by [animation] (0 → 1), decaying to rest.
class Shake extends StatelessWidget {
  const Shake({required this.animation, required this.child, super.key});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (BuildContext context, Widget? child) {
        final t = animation.value;
        final dx = math.sin(t * math.pi * 6) * AppSizes.shakeOffset * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
    );
  }
}
