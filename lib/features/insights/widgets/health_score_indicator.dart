import 'dart:math';
import 'package:flutter/material.dart';

/// Circular health score indicator with animated arc.
class HealthScoreIndicator extends StatelessWidget {
  final int score;
  final double size;
  final double strokeWidth;

  const HealthScoreIndicator({
    super.key,
    required this.score,
    this.size = 72,
    this.strokeWidth = 6,
  });

  Color get _color {
    if (score >= 70) return const Color(0xFF2E7D32);
    if (score >= 40) return const Color(0xFFEF6C00);
    return const Color(0xFFD32F2F);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ScoreArcPainter(
          score: score,
          color: _color,
          strokeWidth: strokeWidth,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score',
                style: TextStyle(
                  fontSize: size * 0.3,
                  fontWeight: FontWeight.bold,
                  color: _color,
                ),
              ),
              Text(
                'HEALTH',
                style: TextStyle(
                  fontSize: size * 0.1,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreArcPainter extends CustomPainter {
  final int score;
  final Color color;
  final double strokeWidth;

  _ScoreArcPainter({
    required this.score,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    // Background arc
    final bgPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -pi * 0.75, pi * 1.5, false, bgPaint);

    // Score arc
    final scorePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final sweepAngle = (score / 100) * pi * 1.5;
    canvas.drawArc(rect, -pi * 0.75, sweepAngle, false, scorePaint);
  }

  @override
  bool shouldRepaint(covariant _ScoreArcPainter old) =>
      old.score != score || old.color != color;
}
