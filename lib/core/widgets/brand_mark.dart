import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Nordic Ledger mark: a navy rounded tile with a white ledger glyph
/// (three decreasing bars, a sage dot on the top bar).
///
/// 96dp (radius 24) on the splash, 64dp (radius 16) on sign-in / MPIN.
class BrandMark extends StatelessWidget {
  const BrandMark({this.size = AppSizes.brandTileMd, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = size >= AppSizes.brandTileLg
        ? AppRadii.xlAll
        : AppRadii.lgAll;
    return Semantics(
      label: 'Nordic Ledger',
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: radius,
        ),
        child: const CustomPaint(painter: _LedgerGlyphPainter()),
      ),
    );
  }
}

class _LedgerGlyphPainter extends CustomPainter {
  const _LedgerGlyphPainter();

  // Glyph geometry as fractions of the tile side.
  static const double _left = 0.24;
  static const double _barHeight = 0.08;
  static const double _gap = 0.12;
  static const List<double> _widths = <double>[0.52, 0.40, 0.28];
  static const double _dotRadius = 0.06;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final bar = Paint()..color = AppColors.onPrimary;
    final barH = s * _barHeight;
    final totalH = barH * _widths.length + s * _gap * (_widths.length - 1);
    var top = (size.height - totalH) / 2;
    Rect? first;
    for (final w in _widths) {
      final rect = Rect.fromLTWH(s * _left, top, s * w, barH);
      first ??= rect;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(barH / 2)),
        bar,
      );
      top += barH + s * _gap;
    }
    final topBar = first!;
    canvas.drawCircle(
      Offset(topBar.right + s * _dotRadius * 2, topBar.center.dy),
      s * _dotRadius,
      Paint()..color = AppColors.collected,
    );
  }

  @override
  bool shouldRepaint(covariant _LedgerGlyphPainter oldDelegate) => false;
}
