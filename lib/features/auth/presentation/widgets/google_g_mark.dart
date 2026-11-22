import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Four-colour Google "G", drawn locally (no network images, works offline).
class GoogleGMark extends StatelessWidget {
  const GoogleGMark({this.size = AppSizes.googleMark, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: const CustomPaint(painter: _GooglePainter()),
      ),
    );
  }
}

class _GooglePainter extends CustomPainter {
  const _GooglePainter();

  static double _rad(double degrees) => degrees * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final stroke = s * 0.2;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: (s - stroke) / 2,
    );
    Paint arc(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    // Canvas angles: 0° = right, clockwise.
    canvas
      ..drawArc(rect, _rad(0), _rad(45), false, arc(AppColors.googleBlue))
      ..drawArc(rect, _rad(45), _rad(90), false, arc(AppColors.googleGreen))
      ..drawArc(rect, _rad(135), _rad(70), false, arc(AppColors.googleYellow))
      ..drawArc(rect, _rad(205), _rad(115), false, arc(AppColors.googleRed))
      ..drawRect(
        Rect.fromLTRB(
          rect.center.dx,
          rect.center.dy - stroke / 2,
          rect.right + stroke / 2,
          rect.center.dy + stroke / 2,
        ),
        Paint()..color = AppColors.googleBlue,
      );
  }

  @override
  bool shouldRepaint(covariant _GooglePainter oldDelegate) => false;
}
