import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// A card with a dashed 1px border (radius 16), used for computed
/// auto-extension rows so they read as "planned, not stored".
class DashedBorderCard extends StatelessWidget {
  const DashedBorderCard({
    required this.child,
    this.color = AppColors.textTertiary,
    this.fill = AppColors.pressed,
    super.key,
  });

  final Widget child;
  final Color color;
  final Color fill;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _DashedBorderPainter(color: color, fill: fill),
    child: Padding(padding: AppInsets.cardCompact, child: child),
  );
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.fill});

  final Color color;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(AppRadii.lg),
    ).deflate(AppSizes.borderWidth / 2);
    canvas.drawRRect(rrect, Paint()..color = fill);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppSizes.borderWidth;
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final end = (d + AppSizes.dashLength).clamp(0, metric.length);
        canvas.drawPath(metric.extractPath(d, end.toDouble()), stroke);
        d += AppSizes.dashLength + AppSizes.dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.fill != fill;
}
