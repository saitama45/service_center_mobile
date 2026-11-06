import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'brand_art.dart';

/// Parses the traced artwork's path data. It only ever holds absolute M, L, C
/// and Z commands with plain positive numbers, which is all this reads.
Path parseBrandPath(String d) {
  final cached = _pathCache[d];
  if (cached != null) return cached;
  final tokens = RegExp(r'[MLCZ]|\d*\.?\d+')
      .allMatches(d)
      .map((m) => m.group(0)!)
      .toList();
  final path = Path();
  var i = 0;
  var command = 'M';
  double next() => double.parse(tokens[i++]);
  while (i < tokens.length) {
    final t = tokens[i];
    if (t == 'Z') {
      path.close();
      i++;
      continue;
    }
    if (t == 'M' || t == 'L' || t == 'C') {
      command = t;
      i++;
    }
    if (command == 'M') {
      path.moveTo(next(), next());
      command = 'L'; // Further pairs after a move are lines, as in SVG.
    } else if (command == 'L') {
      path.lineTo(next(), next());
    } else {
      path.cubicTo(next(), next(), next(), next(), next(), next());
    }
  }
  return _pathCache[d] = path;
}

final Map<String, Path> _pathCache = {};

/// A circle cut by hand — "human and imperfect" (brand book p17). The same
/// seed always gives the same edge, so a card never shimmers between builds.
Path handCutCircle(Offset center, double radius, int seed) {
  const n = 24;
  final points = List.generate(n, (i) {
    final a = i / n * math.pi * 2;
    final k = 1 +
        math.sin(a * 3 + seed * 1.7) * 0.009 +
        math.sin(a * 5 + seed * 2.9) * 0.006;
    return Offset(center.dx + radius * k * math.cos(a),
        center.dy + radius * k * math.sin(a));
  });
  final path = Path()..moveTo(points[0].dx, points[0].dy);
  for (var i = 0; i < n; i++) {
    final p0 = points[(i + n - 1) % n];
    final p1 = points[i];
    final p2 = points[(i + 1) % n];
    final p3 = points[(i + 2) % n];
    path.cubicTo(
      p1.dx + (p2.dx - p0.dx) / 6,
      p1.dy + (p2.dy - p0.dy) / 6,
      p2.dx - (p3.dx - p1.dx) / 6,
      p2.dy - (p3.dy - p1.dy) / 6,
      p2.dx,
      p2.dy,
    );
  }
  return path..close();
}

/// The hero logo (p20). The default Roasted Black disc sits on light
/// surfaces; [onDark] gives the creamy white version, which the book allows
/// only on dark backgrounds (p21). Keep clear space around it (p25).
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 56, this.onDark = false});

  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'The Coffee Bean & Tea Leaf',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _LogoPainter(onDark)),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.onDark);

  final bool onDark;

  @override
  void paint(Canvas canvas, Size size) {
    final disc = onDark ? AppColors.creamyWhite : AppColors.roastedBlack;
    final ink = onDark ? AppColors.roastedBlack : AppColors.creamyWhite;
    canvas.save();
    canvas.scale(size.width / BrandArt.logoViewBox);
    canvas.drawCircle(const Offset(BrandArt.logoCx, BrandArt.logoCy),
        BrandArt.logoR, Paint()..color = disc);
    canvas.drawPath(
        parseBrandPath(BrandArt.logoDetail), Paint()..color = ink);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.onDark != onDark;
}

/// One of the book's hand-drawn marks, sized by [width].
class BrandMark extends StatelessWidget {
  const BrandMark(this.data, {super.key, required this.width, this.color});

  /// The bean and leaf (p37). Never rotated, never in place of the logo.
  const BrandMark.motif({super.key, required this.width, this.color})
      : data = BrandArt.motif;

  /// The wave that underlines a key moment's headline.
  const BrandMark.squiggle({super.key, required this.width, this.color})
      : data = BrandArt.squiggle;

  /// The sunburst behind a stamp that has just landed.
  const BrandMark.burst({super.key, required this.width, this.color})
      : data = BrandArt.burst;

  final BrandMarkData data;
  final double width;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: width * data.height / data.width,
        child: CustomPaint(
            painter: _MarkPainter(data, color ?? AppColors.roastedBlack)),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.data, this.color);

  final BrandMarkData data;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / data.width);
    canvas.drawPath(parseBrandPath(data.path), Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.data != data || old.color != color;
}

/// The Purple Aura light streak (p40): hot at the frame edge, gone by its
/// inner side. The book allows one per layout, near the edge of the frame,
/// and in-app keeps it for key moments only (p41). It rises into place.
class PurpleAura extends StatelessWidget {
  const PurpleAura({
    super.key,
    required this.width,
    this.side = AxisDirection.right,
    this.delay = Duration.zero,
  });

  final double width;

  /// The edge of the frame it hugs: [AxisDirection.left] or right.
  final AxisDirection side;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        child: still
            ? CustomPaint(painter: _AuraPainter(side))
            : _Delayed(
                delay: delay,
                duration: const Duration(milliseconds: 900),
                curve: BrandCurves.slowOut,
                builder: (t) => ClipRect(
                  clipper: _RiseClipper(t),
                  child: CustomPaint(painter: _AuraPainter(side)),
                ),
              ),
      ),
    );
  }
}

class _AuraPainter extends CustomPainter {
  _AuraPainter(this.side);

  final AxisDirection side;

  @override
  void paint(Canvas canvas, Size size) {
    final left = side == AxisDirection.left;
    final rect = Offset.zero & size;
    final across = LinearGradient(
      begin: left ? Alignment.centerRight : Alignment.centerLeft,
      end: left ? Alignment.centerLeft : Alignment.centerRight,
      colors: [
        AppColors.purplePop.withValues(alpha: 0),
        AppColors.purplePop.withValues(alpha: 0.7),
        AppColors.purplePop,
      ],
      stops: const [0, 0.55, 1],
    );
    canvas.drawRect(rect, Paint()..shader = across.createShader(rect));
    // The streak runs violet at the top to magenta at the bottom, as in p40.
    final edge = Rect.fromLTWH(
        left ? 0 : size.width / 2, 0, size.width / 2, size.height);
    const down = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xD97B3FF0), Color(0x00B468E4), Color(0xD9E24DF2)],
    );
    canvas.drawRect(edge, Paint()..shader = down.createShader(edge));
  }

  @override
  bool shouldRepaint(_AuraPainter old) => old.side != side;
}

class _RiseClipper extends CustomClipper<Rect> {
  _RiseClipper(this.t);

  final double t;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(0, size.height * (1 - t), size.width, size.height);

  @override
  bool shouldReclip(_RiseClipper old) => old.t != t;
}

// ── Motion ────────────────────────────────────────────────────────────────

/// The curves Option D's motion is built from (design/src/themes.js).
class BrandCurves {
  BrandCurves._();

  /// Weighted, no bounce: the pour and the press.
  static const Cubic press = Cubic(0.7, 0, 0.2, 1);

  /// Long ease-out: the aura rising, the code button opening.
  static const Cubic slowOut = Cubic(0.16, 1, 0.3, 1);

  /// Text rising from its mask line.
  static const Cubic out = Cubic(0.2, 0.9, 0.2, 1);
}

/// Runs [builder] from 0 to 1 once, after [delay]. Shows the end state at once
/// when the platform asks for reduced motion.
class _Delayed extends StatefulWidget {
  const _Delayed({
    required this.delay,
    required this.duration,
    required this.curve,
    required this.builder,
  });

  final Duration delay;
  final Duration duration;
  final Curve curve;
  final Widget Function(double t) builder;

  @override
  State<_Delayed> createState() => _DelayedState();
}

class _DelayedState extends State<_Delayed>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);
  Timer? _start;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      _start = Timer(widget.delay, _c.forward);
    }
  }

  @override
  void dispose() {
    _start?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) => widget.builder(widget.curve.transform(_c.value)),
      );
}

/// Pressed on like a seal: drops from larger, lands, and the surface gives a
/// little. Used for the logo on the splash and sign-in.
class SealIn extends StatelessWidget {
  const SealIn({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    return _Delayed(
      delay: delay,
      duration: const Duration(milliseconds: 540),
      curve: Curves.linear,
      builder: (t) {
        // 0–48%: the drop (ease-in). 48–100%: the surface gives and settles.
        final drop = (t / 0.48).clamp(0.0, 1.0);
        final settle = ((t - 0.48) / 0.52).clamp(0.0, 1.0);
        final scale = t < 0.48
            ? 1.45 - 0.45 * Curves.easeIn.transform(drop)
            : 1 + 0.03 * math.sin(math.pi * settle);
        return Opacity(
          opacity: (drop * 3).clamp(0.0, 1.0),
          child: Transform.scale(scale: scale, child: child),
        );
      },
    );
  }
}

/// A stamp pressed down by hand: 200 ms, eased in, no overshoot.
class PressIn extends StatelessWidget {
  const PressIn({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    return _Delayed(
      delay: delay,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeIn,
      builder: (t) => Opacity(
        opacity: (t * 2.5).clamp(0.0, 1.0),
        child: Transform.scale(scale: 1.5 - 0.5 * t, child: child),
      ),
    );
  }
}
