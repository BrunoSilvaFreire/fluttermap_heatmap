import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Bitmap and RGBA32BitmapHeader', () {
    test('Bitmap size calculation and cloneHeadless', () {
      final content = Uint8List(2 * 2 * bitmapPixelLength);
      content.fillRange(0, content.length, 128);

      final bitmap = Bitmap.fromHeadless(2, 2, content);
      expect(bitmap.size, equals(16));

      final clone = bitmap.cloneHeadless();
      expect(clone.width, equals(2));
      expect(clone.height, equals(2));
      expect(clone.size, equals(16));
      expect(clone.content, equals(content));
      expect(identical(clone.content, bitmap.content), isFalse);
    });

    test('buildHeaded creates valid BMP bytes with header', () {
      final content = Uint8List(2 * 2 * bitmapPixelLength);
      final bitmap = Bitmap.fromHeadless(2, 2, content);
      final headed = bitmap.buildHeaded();

      expect(headed.length, equals(16 + rgba32HeaderSize));
      // Check BM signature
      expect(headed[0], equals(0x42));
      expect(headed[1], equals(0x4d));
    });

    test('buildImage returns decoded ui.Image', () async {
      final content = Uint8List(4 * 4 * bitmapPixelLength);
      // Fill with opaque blue
      for (int i = 0; i < content.length; i += 4) {
        content[i] = 0; // R
        content[i + 1] = 0; // G
        content[i + 2] = 255; // B
        content[i + 3] = 255; // A
      }
      final bitmap = Bitmap.fromHeadless(4, 4, content);
      final image = await bitmap.buildImage();
      expect(image.width, equals(4));
      expect(image.height, equals(4));
    });
  });

  group('Circle Painters', () {
    test('BaseCirclePainter paints without error and shouldRepaint returns false', () {
      final painter = BaseCirclePainter(radius: 20.0, blurFactor: 0.5);
      expect(painter.shouldRepaint(painter), isFalse);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(100, 100));
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('AltBaseCirclePainter paints without error and shouldRepaint returns false', () {
      final painter = AltBaseCirclePainter(radius: 25.0, blurFactor: 0.6);
      expect(painter.shouldRepaint(painter), isFalse);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(100, 100));
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });
  });

  group('GrayScaleHeatMapPainter and DataPoint', () {
    test('DataPoint constructors, fromOffset and merge', () {
      final p1 = DataPoint(10.0, 20.0, 1.0);
      expect(p1.x, equals(10.0));
      expect(p1.y, equals(20.0));
      expect(p1.z, equals(1.0));

      final p2 = DataPoint.fromOffset(const Offset(30.0, 40.0));
      expect(p2.x, equals(30.0));
      expect(p2.y, equals(40.0));
      expect(p2.z, equals(1.0));

      p2.merge(10.0, 20.0, 1.0);
      // merge:
      // x = (10 * 1 + 30 * 1) / (1 + 1) = 20
      // y = (20 * 1 + 40 * 1) / (1 + 1) = 30
      // z = 1 + 1 = 2
      expect(p2.x, equals(20.0));
      expect(p2.y, equals(30.0));
      expect(p2.z, equals(2.0));
    });

    test('GrayScaleHeatMapPainter paints with baseCircle and points', () async {
      final content = Uint8List(10 * 10 * bitmapPixelLength);
      final bitmap = Bitmap.fromHeadless(10, 10, content);
      final baseCircle = await bitmap.buildImage();

      final points = [
        DataPoint(15.0, 15.0, 0.5),
        DataPoint(30.0, 30.0, 1.8),
      ];

      final painter = GrayScaleHeatMapPainter(
        baseCircle: baseCircle,
        data: points,
        buffer: 5.0,
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(100, 100));
      final picture = recorder.endRecording();
      expect(picture, isNotNull);

      // shouldRepaint logic
      final otherPainterSame = GrayScaleHeatMapPainter(
        baseCircle: baseCircle,
        data: points,
      );
      expect(painter.shouldRepaint(otherPainterSame), isFalse);

      final otherPainterDiff = GrayScaleHeatMapPainter(
        baseCircle: baseCircle,
        data: [DataPoint(1, 1, 1)],
      );
      expect(painter.shouldRepaint(otherPainterDiff), isTrue);
    });
  });

  group('HeatMapPainter and HeatMapState', () {
    test('HeatMapPainter paints image and shouldRepaint returns true', () async {
      final content = Uint8List(4 * 4 * bitmapPixelLength);
      final bitmap = Bitmap.fromHeadless(4, 4, content);
      final img = await bitmap.buildImage();

      final painter = HeatMapPainter(img);
      expect(painter.shouldRepaint(painter), isTrue);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(10, 10));
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('HeatMapState lifecycle', () {
      final state = HeatMapState(HeatMapOptions());
      expect(state.imageSink, isNotNull);
      expect(state.imageSink!.isClosed, isFalse);

      state.dispose();
      expect(state.imageSink!.isClosed, isTrue);
    });
  });
}
