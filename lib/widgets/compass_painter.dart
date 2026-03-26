import 'dart:math';
import 'package:flutter/material.dart';

/// Paints a compass rose that rotates so that geographic north always
/// points upward on the screen.
///
/// Draws an outer circle, tick marks every 30 degrees, N/E/S/W labels,
/// and a red north-pointing triangle. The entire canvas is rotated by
/// `-(heading * pi / 180)` so the rose tracks the device heading.
class CompassPainter extends CustomPainter {
  /// The current device heading in degrees (0-360), or null if unavailable.
  final double? heading;

  /// Color used for the circle, ticks, and non-north cardinal labels.
  final Color primaryColor;

  /// Color used for the north label and north-pointing triangle.
  final Color accentColor;

  CompassPainter({
    required this.heading,
    required this.primaryColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    final angle = -(heading ?? 0.0) * pi / 180;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    // Outer circle.
    final circlePaint = Paint()
      ..color = primaryColor.withAlpha(80)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset.zero, radius, circlePaint);

    // Tick marks every 30 degrees.
    final tickPaint = Paint()
      ..color = primaryColor.withAlpha(150)
      ..strokeWidth = 1.5;
    for (int i = 0; i < 12; i++) {
      final tickAngle = i * 30 * pi / 180;
      final outer = Offset(radius * cos(tickAngle - pi / 2),
          radius * sin(tickAngle - pi / 2));
      final tickLength = (i % 3 == 0) ? 12.0 : 6.0;
      final inner = Offset((radius - tickLength) * cos(tickAngle - pi / 2),
          (radius - tickLength) * sin(tickAngle - pi / 2));
      canvas.drawLine(inner, outer, tickPaint);
    }

    // Cardinal labels: N, E, S, W.
    const cardinals = ['N', 'E', 'S', 'W'];
    const angles = [0.0, 90.0, 180.0, 270.0];
    for (int i = 0; i < 4; i++) {
      final labelAngle = angles[i] * pi / 180 - pi / 2;
      final labelRadius = radius - 24;
      final offset = Offset(
        labelRadius * cos(labelAngle),
        labelRadius * sin(labelAngle),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: cardinals[i],
          style: TextStyle(
            color: cardinals[i] == 'N' ? accentColor : primaryColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, offset - Offset(tp.width / 2, tp.height / 2));
    }

    // Red north-pointing triangle.
    final trianglePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;
    final trianglePath = Path()
      ..moveTo(0, -(radius - 4))
      ..lineTo(-6, -(radius - 16))
      ..lineTo(6, -(radius - 16))
      ..close();
    canvas.drawPath(trianglePath, trianglePaint);

    canvas.restore();

    // Degree text at center (drawn in screen-space, not rotated).
    final degreeText = heading != null
        ? '${heading!.round() % 360}°'
        : '--°';
    final degreeFontSize = radius * 0.18;
    final degreePainter = TextPainter(
      text: TextSpan(
        text: degreeText,
        style: TextStyle(
          color: const Color(0xFFFFFFFF),
          fontSize: degreeFontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    degreePainter.paint(
      canvas,
      Offset(
        center.dx - degreePainter.width / 2,
        center.dy - degreePainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(CompassPainter oldDelegate) {
    return oldDelegate.heading != heading ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.accentColor != accentColor;
  }
}
