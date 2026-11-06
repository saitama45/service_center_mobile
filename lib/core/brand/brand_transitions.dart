import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_colors.dart';
import 'brand_widgets.dart';

/// Golden Caramel pours down the screen on a moving wave, the way milk meets
/// coffee in the brand book's key visuals (p44), and the next screen appears
/// behind it. For moves between whole sections: splash, sign-in, the app.
CustomTransitionPage<void> pourPage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 840),
    reverseTransitionDuration: const Duration(milliseconds: 840),
    transitionsBuilder: (context, animation, secondary, child) {
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
        return FadeTransition(opacity: animation, child: child);
      }
      return AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) {
          final t = animation.value;
          // First half the caramel covers the old screen; second half it
          // drains away and uncovers the new one.
          return Stack(
            fit: StackFit.expand,
            children: [
              Opacity(opacity: t < 0.5 ? 0 : 1, child: child),
              IgnorePointer(
                child: CustomPaint(painter: _PourPainter(t)),
              ),
            ],
          );
        },
      );
    },
  );
}

class _PourPainter extends CustomPainter {
  _PourPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final covering = t < 0.5;
    final v = BrandCurves.press.transform(covering ? t * 2 : t * 2 - 1);
    final y = -40 + (size.height + 80) * v;
    final amp = 30 * math.sin(math.pi * v);
    final phase = covering ? 0.0 : 2.0;
    final edge = Path();
    if (covering) {
      edge.moveTo(0, 0);
      edge.lineTo(size.width, 0);
    } else {
      edge.moveTo(0, size.height);
      edge.lineTo(size.width, size.height);
    }
    double waveAt(double x) => y + amp * math.sin(x / 62 + phase + v * 5);
    for (var x = size.width; x > 0; x -= 12) {
      edge.lineTo(x, waveAt(x));
    }
    edge.lineTo(0, waveAt(0)); // Always reach the left edge exactly.
    edge.close();
    canvas.drawPath(edge, Paint()..color = AppColors.goldenCaramel);
  }

  @override
  bool shouldRepaint(_PourPainter old) => old.t != t;
}

/// The caramel member-code button grows into the page, then rolls away: one
/// shape, never cut. [origin] is where the button sits, as a fraction of the
/// screen; the default is the bottom-right placement of the home button.
CustomTransitionPage<void> revealFromButtonPage({
  required LocalKey key,
  required Widget child,
  Alignment origin = const Alignment(0.82, 0.74),
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 800),
    reverseTransitionDuration: const Duration(milliseconds: 420),
    transitionsBuilder: (context, animation, secondary, child) {
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
        return FadeTransition(opacity: animation, child: child);
      }
      return AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) => ClipPath(
          clipper: _CircleClipper(origin, BrandCurves.press.transform(animation.value)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              child!,
              // The caramel shape leads, then fades off the finished page.
              IgnorePointer(
                child: Opacity(
                  opacity:
                      (1 - (animation.value - 0.35) / 0.35).clamp(0.0, 1.0),
                  child: const ColoredBox(color: AppColors.goldenCaramel),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _CircleClipper extends CustomClipper<Path> {
  _CircleClipper(this.origin, this.t);

  final Alignment origin;
  final double t;

  @override
  Path getClip(Size size) {
    final center = origin.alongSize(size);
    final far = [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ].map((c) => (c - center).distance).reduce(math.max);
    return Path()
      ..addOval(Rect.fromCircle(center: center, radius: 30 + (far - 30) * t));
  }

  @override
  bool shouldReclip(_CircleClipper old) => old.t != t || old.origin != origin;
}
