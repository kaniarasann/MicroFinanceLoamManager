import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Thin progress / share bar: [color] fill over the `track` colour.
/// [bps] is basis points (10000 = full); values outside 0–10000 clamp.
class ShareBar extends StatelessWidget {
  const ShareBar({
    required this.bps,
    required this.color,
    this.height = AppSizes.shareBarHeight,
    super.key,
  });

  final int bps;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final clamped = bps < 0 ? 0 : (bps > 10000 ? 10000 : bps);
    return ClipRRect(
      borderRadius: AppRadii.fullAll,
      child: SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: const BoxDecoration(color: AppColors.track),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: FractionallySizedBox(
              widthFactor: clamped / 10000,
              heightFactor: 1,
              child: DecoratedBox(decoration: BoxDecoration(color: color)),
            ),
          ),
        ),
      ),
    );
  }
}
