import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// "Lemniscate Bloom" splash — a Bernoulli lemniscate drawn with a sweeping
/// particle trail and a slow pulsing bloom, matching the web reference
/// exactly (24 particles, trail span 0.5, 480-step path, 5.6s sweep loop).
class LemniscateSplash extends StatefulWidget {
  final String title;
  final String tag;
  final Widget? bottom;
  final double? size;

  const LemniscateSplash({
    super.key,
    this.title = '',
    this.tag = '',
    this.bottom,
    this.size,
  });

  @override
  State<LemniscateSplash> createState() => _LemniscateSplashState();
}

class _LemniscateSplashState extends State<LemniscateSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final double _startTime;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now().millisecondsSinceEpoch.toDouble();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    final frameSize = widget.size ?? math.min(shortestSide * 0.72, 420.0);

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: frameSize,
          height: frameSize,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (_, _) {
              final elapsed = DateTime.now().millisecondsSinceEpoch.toDouble() - _startTime;
              return CustomPaint(
                size: Size.square(frameSize),
                painter: _LemniscatePainter(
                  progress: _controller.value,
                  elapsed: elapsed,
                ),
              );
            },
          ),
        ),
        if (widget.title.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            widget.title,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFF5F5F5),
            ),
          ),
        ],
        if (widget.tag.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            widget.tag,
            style: TextStyle(
              fontSize: 13,
              letterSpacing: 2.34,
              color: Colors.white.withValues(alpha: 0.58),
            ),
          ),
        ],
      ],
    );

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: SafeArea(
        child: widget.bottom == null
            // Centered loading screen (no extra chrome).
            ? Center(child: content)
            : Stack(
                alignment: Alignment.center,
                children: [
                  Center(child: content),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 24,
                    child: widget.bottom!,
                  ),
                ],
              ),
      ),
    );
  }
}

class _LemniscatePainter extends CustomPainter {
  final double progress;
  final double elapsed;

  _LemniscatePainter({required this.progress, required this.elapsed});

  // Exact web reference config (viewBox 0..100, centre 50,50).
  static const int particleCount = 24;
  static const double trailSpan = 0.5;
  static const double pulseDurationMs = 2900.0;
  static const double strokeWidth = 3.0;
  static const double lemniscateA = 19.5;
  static const double lemniscateBoost = 4.3;

  double _normalizeProgress(double p) => ((p % 1) + 1) % 1;

  double _detailScale(double time) {
    final pulseProgress = (time % pulseDurationMs) / pulseDurationMs;
    final pulseAngle = pulseProgress * math.pi * 2;
    return 0.52 + ((math.sin(pulseAngle + 0.55) + 1) / 2) * 0.48;
  }

  Offset _point(double t, double detailScale, Offset center, double unit) {
    final scale = lemniscateA + detailScale * lemniscateBoost;
    final cosT = math.cos(t);
    final sinT = math.sin(t);
    final denom = 1 + sinT * sinT;
    return Offset(
      center.dx + (scale * cosT) / denom * unit,
      center.dy + (scale * sinT * cosT) / denom * unit,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final time = elapsed;
    final center = Offset(size.width / 2, size.height / 2);
    final unit = size.shortestSide / 100.0;
    final detailScale = _detailScale(time);

    final pathPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * unit
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final steps = 480;
    for (int i = 0; i <= steps; i++) {
      final p = _point(i / steps * math.pi * 2, detailScale, center, unit);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(path, pathPaint);

    for (int i = 0; i < particleCount; i++) {
      final tailOffset = i / (particleCount - 1);
      final pointProgress = _normalizeProgress(progress - tailOffset * trailSpan);
      final p = _point(pointProgress * math.pi * 2, detailScale, center, unit);
      final fade = math.pow(1 - tailOffset, 0.56).toDouble();

      final particlePaint = Paint()
        ..color = Colors.white.withValues(alpha: (0.04 + fade * 0.96).clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(p.dx, p.dy),
        (0.9 + fade * 2.7) * unit,
        particlePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_LemniscatePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.elapsed != elapsed;
}
