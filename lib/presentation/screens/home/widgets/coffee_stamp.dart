import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../../core/brand/brand_art.dart';
import '../../../../core/brand/brand_widgets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';

/// A single slot on the stamp card, drawn rather than imaged so it stays crisp
/// at any size and can animate when newly filled.
///
/// Every slot is a coin cut by hand ("human and imperfect", brand book p17).
/// A filled regular slot carries the brand's coffee bean and tea leaf (p37),
/// always upright because the book asks that the motif is never rotated. An
/// empty slot is a faint ring with a centre dot. A [holiday] slot is Golden
/// Caramel with a star, filled or empty, so a member can tell the Holiday
/// slots apart from the regular ones at a glance.
///
/// Drawn for the Roasted Black stamp card; [seed] varies the cut of the edge
/// from slot to slot.
class CoffeeStamp extends StatelessWidget {
  const CoffeeStamp({
    super.key,
    required this.filled,
    this.size = 32,
    this.highlight = false,
    this.holiday = false,
    this.seed = 0,
  });

  final bool filled;
  final double size;

  /// The stamp that was just earned: it is pressed onto the card.
  final bool highlight;

  /// One of the campaign's Holiday slots rather than a regular one.
  final bool holiday;

  final int seed;

  @override
  Widget build(BuildContext context) {
    final coin = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _StampPainter(filled: filled, holiday: holiday, seed: seed),
      ),
    );
    // Lands a beat after the card does, so the member sees it arrive.
    return highlight
        ? PressIn(delay: const Duration(milliseconds: 520), child: coin)
        : coin;
  }
}

class _StampPainter extends CustomPainter {
  _StampPainter({
    required this.filled,
    required this.holiday,
    required this.seed,
  });

  final bool filled;
  final bool holiday;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final s = size.width / 34; // reference geometry is drawn at 34pt
    final cut = handCutCircle(c, size.width / 2 - 1.5, seed);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.4, 1.5 * s);

    if (holiday) {
      final star = _star(c, 8.6 * s, 3.7 * s);
      if (filled) {
        canvas.drawPath(cut, Paint()..color = AppColors.goldenCaramel);
        canvas.drawPath(star, Paint()..color = AppColors.roastedBlack);
      } else {
        canvas.drawPath(cut, ring..color = AppColors.goldenCaramel);
        canvas.drawPath(
          star,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1 * s
            ..strokeJoin = StrokeJoin.round
            ..color = AppColors.goldenCaramel.withValues(alpha: 0.8),
        );
      }
      return;
    }

    if (!filled) {
      canvas.drawPath(
          cut, ring..color = AppColors.creamyWhite.withValues(alpha: 0.38));
      canvas.drawCircle(c, 2.6 * s,
          Paint()..color = AppColors.creamyWhite.withValues(alpha: 0.3));
      return;
    }

    canvas.drawPath(cut, Paint()..color = AppColors.creamyWhite);
    if (size.width < 24) {
      _paintBean(canvas, c, s);
      return;
    }
    // The bean and leaf, 80% of the coin, centred and upright.
    const m = BrandArt.stampMotif;
    final k = size.width * 0.8 / m.width;
    canvas.save();
    canvas.translate(c.dx - m.width * k / 2, c.dy - m.height * k / 2);
    canvas.scale(k);
    canvas.drawPath(
        parseBrandPath(m.path), Paint()..color = AppColors.roastedBlack);
    canvas.restore();
  }

  /// Too small for the drawn motif (the legend): a plain bean with its seam.
  void _paintBean(Canvas canvas, Offset c, double s) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-24 * math.pi / 180);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 21 * s, height: 14.4 * s),
      Paint()..color = AppColors.roastedBlack,
    );
    canvas.restore();
    final seam = Path()
      ..moveTo(c.dx - 9.4 * s, c.dy + 3.8 * s)
      ..cubicTo(c.dx - 4 * s, c.dy + 0.2 * s, c.dx - 1.8 * s, c.dy + 3.8 * s,
          c.dx + 1.6 * s, c.dy + 0.6 * s)
      ..cubicTo(c.dx + 4.2 * s, c.dy - 1.9 * s, c.dx + 6 * s, c.dy - 2 * s,
          c.dx + 9.4 * s, c.dy - 3.8 * s);
    canvas.drawPath(
      seam,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * s
        ..strokeCap = StrokeCap.round
        ..color = AppColors.creamyWhite,
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
      old.filled != filled || old.holiday != holiday || old.seed != seed;
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
    this.stampSize = 50,
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

  /// Presses the most recent stamp onto the card as it appears.
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
        const minGap = 8.0;
        final width =
            (constraints.maxWidth - minGap * (perRow - 1)) / perRow;
        final size = width.clamp(0.0, stampSize);

        return Wrap(
          spacing: minGap,
          runSpacing: 12,
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
                  seed: i,
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

/// "★ 4 Holiday · ● 16 Regular" under a card that has Holiday slots, with
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

  /// Text colour; defaults to California Cream for the dark stamp card.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.caption.copyWith(
      color: color ?? AppColors.californiaCream,
    );

    return Row(
      children: [
        const CoffeeStamp(filled: true, holiday: true, size: 16),
        const SizedBox(width: 6),
        Text('$holidaySlots Holiday', style: style),
        Text('  ·  ', style: style),
        const CoffeeStamp(filled: true, size: 16, seed: 3),
        const SizedBox(width: 6),
        Text('$regularSlots Regular', style: style),
      ],
    );
  }
}
