import 'dart:ui';

import 'package:flutter/material.dart' hide Image;

/// Painter for creating a grayscale version of the heatmap by painting the base image
/// for each provided data point.
///
/// Point weights are expected to arrive already normalized to `[0, 1]` (the
/// heat map tool does the normalization). Each weight is mapped linearly onto
/// `[minOpacity, 1.0]` so the full gradient is used and relative differences —
/// not raw magnitude — drive color.
class GrayScaleHeatMapPainter extends CustomPainter {
  double minOpacity = 0.3;
  final Image baseCircle;
  double buffer;
  final List<DataPoint> data;

  GrayScaleHeatMapPainter(
      {required this.baseCircle,
      this.buffer = 0,
      required this.data,
      double? minOpacity})
      : minOpacity = minOpacity ?? 0.3;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color.fromRGBO(0, 0, 0, 1);

    // offsets for centering the baseCircle when painting
    final yOffset = baseCircle.height / 2;
    final xOffset = baseCircle.width / 2;
    for (final point in data) {
      final t = point.z.clamp(0.0, 1.0);
      final alpha = minOpacity + (1.0 - minOpacity) * t;

      paint.color = Color.fromRGBO(0, 0, 0, alpha);

      canvas.drawImage(
          baseCircle,
          Offset(point.x + buffer - xOffset, point.y + buffer - yOffset),
          paint);
    }
  }

  @override
  bool shouldRepaint(GrayScaleHeatMapPainter oldDelegate) {
    return oldDelegate.data != data;
  }
}

/// data point representing an x, y coordinate with an intensity
class DataPoint {
  double x;
  double y;
  double z;

  DataPoint(this.x, this.y, this.z);

  factory DataPoint.fromOffset(Offset offset) {
    return DataPoint(offset.dx, offset.dy, 1);
  }

  void merge(double x, double y, double intensity) {
    this.x = (x * intensity + this.x * z) / (intensity + z);
    this.y = (y * intensity + this.y * z) / (intensity + z);
    z = z + intensity;
  }
}
