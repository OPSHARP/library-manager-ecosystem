import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import '../theme/app_colors.dart';

/// Animated lemniscate splash with iOS system colors.
class LemniscateSplash extends StatefulWidget {
  final String title;
  final String tag;
  final Widget? bottom;

  const LemniscateSplash({
    super.key,
    this.title = '',
    this.tag = '',
    this.bottom,
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
    return CupertinoPageScaffold(
      backgroundColor: AppColors.systemGroupedBackground,
      child: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 260,
                    height: 260,
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (_, _) {
                        final elapsed = DateTime.now().millisecondsSinceEpoch.toDouble() - _startTime;
                        return CustomPaint(
                          painter: _LemniscatePainter(
                            progress: _controller.value,
                            elapsed: elapsed,
                          ),
                          size: const Size(260, 260),
                        );
                      },
                    ),
                  ),
                  if (widget.title.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.label,
                        letterSpacing: -0.4,
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
                        color: AppColors.secondaryLabel,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (widget.bottom != null)
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: widget.bottom!,
                ),
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

  static const particleCount = 70;
  static const trailSpan = 0.4;
  static const pulseDuration = 5000.0;

  double _detailScale(double t) {
    final angle = (t % pulseDuration) / pulseDuration * math.pi * 2;
    return 0.52 + ((math.sin(angle + 0.55) + 1) / 2) * 0.48;
  }

  Offset _lemniscatePoint(double t, double scale) {
    final cosT = math.cos(t);
    final sinT = math.sin(t);
    final denom = 1 + sinT * sinT;
    return Offset(
      130 + (scale * cosT) / denom,
      130 + (scale * sinT * cosT) / denom,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final time = elapsed;
    final t = progress * math.pi * 2;
    final detailScale = _detailScale(time);
    final a = 20.0 + detailScale * 7.0;

    final pathPaint = Paint()
      ..color = AppColors.systemBlue.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final steps = 480;
    for (int i = 0; i <= steps; i++) {
      final p = _lemniscatePoint(i / steps * math.pi * 2, a);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(path, pathPaint);

    for (int i = 0; i < particleCount; i++) {
      final tailOffset = i / (particleCount - 1);
      final pt = (t - tailOffset * trailSpan * math.pi * 2);
      final normalizedPt =
          ((pt % (math.pi * 2)) + (math.pi * 2)) % (math.pi * 2);
      final p = _lemniscatePoint(normalizedPt, a);
      final fade = math.pow(1 - tailOffset, 0.56).toDouble();

      final particlePaint = Paint()
        ..color = AppColors.systemBlue
            .withValues(alpha: (0.04 + fade * 0.96).clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
          Offset(p.dx, p.dy), 0.9 + fade * 2.7, particlePaint);
    }
  }

  @override
  bool shouldRepaint(_LemniscatePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.elapsed != elapsed;
}
