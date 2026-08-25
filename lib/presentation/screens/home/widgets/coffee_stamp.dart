import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// A single slot on the stamp card, drawn rather than imaged so it stays crisp
/// at any size and can animate when newly filled.
///
/// Filled slots render the coffee-cup mark from the reference design; empty
/// slots are a latte ring with a faint centre dot.
class CoffeeStamp extends StatelessWidget {
  const CoffeeStamp({
    super.key,
    required this.filled,
    this.size = 32,
    this.highlight = false,
  });

  final bool filled;
  final double size;

  /// Draws the amber glow used for the stamp that was just earned.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _StampPainter(filled: filled, highlight: highlight),
      ),
    );
  }
}

class _StampPainter extends CustomPainter {
  _StampPainter({required this.filled, required this.highlight});

  final bool filled;
  final bool highlight;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 1;
    final s = size.width / 34; // reference geometry is drawn at 34pt

    if (!filled) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * s
          ..color = AppColors.latte.withValues(alpha: 0.55),
      );
      canvas.drawCircle(
        c,
        3.5 * s,
        Paint()..color = AppColors.latte.withValues(alpha: 0.35),
      );
      return;
    }

    if (highlight) {
      canvas.drawCircle(
        c,
        r + 3 * s,
        Paint()
          ..color = AppColors.gold.withValues(alpha: 0.35)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 * s),
      );
    }

    canvas.drawCircle(c, r, Paint()..color = AppColors.amber);

    // Cup — stacked ellipses give the shallow "crema on top" read.
    final cx = c.dx;
    final top = c.dy - size.height / 2;
    void ellipse(double dy, double rx, double ry, Color color) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, top + dy * s),
          width: rx * 2 * s,
          height: ry * 2 * s,
        ),
        Paint()..color = color,
      );
    }

    ellipse(21, 7, 4.5, AppColors.brown);
    ellipse(20.5, 7, 4.5, AppColors.caramel);
    ellipse(20, 6.5, 4, AppColors.brown);
    ellipse(18, 3.5, 2.2, AppColors.darkBrown);

    // Handle
    final handle = Path()
      ..moveTo(cx + 6.5 * s, top + 20 * s)
      ..quadraticBezierTo(cx + 9 * s, top + 17 * s, cx + 7.5 * s, top + 14.5 * s)
      ..quadraticBezierTo(cx + 6 * s, top + 12 * s, cx + 4 * s, top + 13.5 * s);
    canvas.drawPath(
      handle,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * s
        ..strokeCap = StrokeCap.round
        ..color = AppColors.latte,
    );
  }

  @override
  bool shouldRepaint(_StampPainter old) =>
      old.filled != filled || old.highlight != highlight;
}

/// The grid of stamp slots. Lays out 5 per row like the reference card.
class StampGrid extends StatelessWidget {
  const StampGrid({
    super.key,
    required this.collected,
    required this.total,
    this.stampSize = 32,
    this.highlightLast = false,
  });

  final int collected;
  final int total;
  final double stampSize;

  /// Adds the "just earned" glow to the most recent stamp.
  final bool highlightLast;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const perRow = 5;
        const gap = 8.0;
        final width =
            (constraints.maxWidth - gap * (perRow - 1)) / perRow;
        final size = width.clamp(0.0, stampSize);

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: List.generate(total, (i) {
            final filled = i < collected;
            return SizedBox(
              width: width,
              child: Center(
                child: CoffeeStamp(
                  filled: filled,
                  size: size,
                  highlight: highlightLast && i == collected - 1,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
