import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';

/// A single slot on the stamp card, drawn rather than imaged so it stays crisp
/// at any size and can animate when newly filled.
///
/// Filled slots render the coffee-cup mark from the reference design; empty
/// slots are a latte ring with a faint centre dot. A [holiday] slot is drawn
/// in gold with a star instead, filled or empty, so a member can tell the
/// Holiday slots apart from the regular ones at a glance.
class CoffeeStamp extends StatelessWidget {
  const CoffeeStamp({
    super.key,
    required this.filled,
    this.size = 32,
    this.highlight = false,
    this.holiday = false,
  });

  final bool filled;
  final double size;

  /// Draws the amber glow used for the stamp that was just earned.
  final bool highlight;

  /// One of the campaign's Holiday slots rather than a regular one.
  final bool holiday;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _StampPainter(
            filled: filled, highlight: highlight, holiday: holiday),
      ),
    );
  }
}

class _StampPainter extends CustomPainter {
  _StampPainter({
    required this.filled,
    required this.highlight,
    required this.holiday,
  });

  final bool filled;
  final bool highlight;
  final bool holiday;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 1;
    final s = size.width / 34; // reference geometry is drawn at 34pt

    if (holiday) {
      _paintHoliday(canvas, c, r, s);
      return;
    }

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

    _paintGlow(canvas, c, r, s);

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

  /// Gold, with a star in place of the cup. Empty is a gold ring around a
  /// star outline — still clearly gold, so an unfilled Holiday slot never
  /// reads as an ordinary empty slot.
  void _paintHoliday(Canvas canvas, Offset c, double r, double s) {
    final star = _star(c, 8.5 * s, 3.6 * s);

    if (!filled) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * s
          ..color = AppColors.gold.withValues(alpha: 0.8),
      );
      canvas.drawPath(
        star,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2 * s
          ..strokeJoin = StrokeJoin.round
          ..color = AppColors.gold.withValues(alpha: 0.6),
      );
      return;
    }

    _paintGlow(canvas, c, r, s);

    canvas.drawCircle(c, r, Paint()..color = AppColors.gold);
    // A thin inner ring gives it the pressed-seal look of a festive stamp.
    canvas.drawCircle(
      c,
      r - 2.5 * s,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 * s
        ..color = AppColors.darkBrown.withValues(alpha: 0.3),
    );
    canvas.drawPath(star, Paint()..color = AppColors.darkBrown);

    // Two sparkles off the star's shoulder.
    final sparkle = Paint()..color = AppColors.cream.withValues(alpha: 0.9);
    canvas.drawCircle(c + Offset(8.5 * s, -8 * s), 1.3 * s, sparkle);
    canvas.drawCircle(c + Offset(-9 * s, 6.5 * s), 0.9 * s, sparkle);
  }

  void _paintGlow(Canvas canvas, Offset c, double r, double s) {
    if (!highlight) return;
    canvas.drawCircle(
      c,
      r + 3 * s,
      Paint()
        ..color = AppColors.gold.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 * s),
    );
  }

  /// A five-pointed star centred on [c], point up.
  static Path _star(Offset c, double outer, double inner) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final radius = i.isEven ? outer : inner;
      final angle = -math.pi / 2 + i * math.pi / 5;
      final x = c.dx + radius * math.cos(angle);
      final y = c.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_StampPainter old) =>
      old.filled != filled ||
      old.highlight != highlight ||
      old.holiday != holiday;
}

/// The grid of stamp slots. Lays out 5 per row like the reference card.
///
/// With [holidaySlots] > 0 the first that-many positions are Holiday slots and
/// the rest regular; each region fills from its own start, so a card can show
/// full Holiday slots ahead of mostly-empty regular ones. With the default 0
/// it is the plain card it always was.
class StampGrid extends StatelessWidget {
  const StampGrid({
    super.key,
    required this.collected,
    required this.total,
    this.stampSize = 32,
    this.highlightLast = false,
    this.holidaySlots = 0,
    this.holidayCount = 0,
    this.regularCount,
  });

  /// Stamps on the card in total. Only used to derive [regularCount] when it
  /// isn't given.
  final int collected;
  final int total;
  final double stampSize;

  /// Adds the "just earned" glow to the most recent stamp.
  final bool highlightLast;

  final int holidaySlots;

  /// Filled Holiday slots, counted from the start of the Holiday region.
  final int holidayCount;

  /// Filled regular slots, counted from the start of the regular region.
  /// Defaults to `collected - holidayCount`.
  final int? regularCount;

  @override
  Widget build(BuildContext context) {
    final slots = math.max(total, 0);
    final holiday = holidaySlots.clamp(0, slots);
    final holidayFilled = holidayCount.clamp(0, holiday);
    final regularFilled =
        (regularCount ?? collected - holidayFilled).clamp(0, slots - holiday);
    final lastFilled =
        regularFilled > 0 ? holiday + regularFilled - 1 : holidayFilled - 1;

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
          children: List.generate(slots, (i) {
            final isHoliday = i < holiday;
            final filled =
                isHoliday ? i < holidayFilled : i - holiday < regularFilled;
            return SizedBox(
              width: width,
              child: Center(
                child: CoffeeStamp(
                  filled: filled,
                  holiday: isHoliday,
                  size: size,
                  highlight: highlightLast && i == lastFilled,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// "★ 4 Holiday · ☕ 16 Regular" under a card that has Holiday slots, with
/// the two slot marks themselves as the key.
class StampSlotLegend extends StatelessWidget {
  const StampSlotLegend({
    super.key,
    required this.holidaySlots,
    required this.regularSlots,
    this.color,
  });

  final int holidaySlots;
  final int regularSlots;

  /// Text colour; defaults to the muted latte used on the dark hero card.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.caption.copyWith(
      color: color ?? AppColors.latte.withValues(alpha: 0.8),
    );

    return Row(
      children: [
        const CoffeeStamp(filled: true, holiday: true, size: 13),
        const SizedBox(width: 5),
        Text('$holidaySlots Holiday', style: style),
        Text('  ·  ', style: style),
        const CoffeeStamp(filled: true, size: 13),
        const SizedBox(width: 5),
        Text('$regularSlots Regular', style: style),
      ],
    );
  }
}
