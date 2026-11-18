import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';
import 'transparent.dart';

class HeatMap {
  HeatMap(this.options, this.width, this.height, this.data) {
    _initColorPalette();
  }

  final HeatMapOptions options;
  final int width;
  final int height;
  final List<DataPoint> data;

  late ByteData _palette;
  final Completer<void> ready = Completer<void>();

  /// Base Shapes used to represent each point
  final Map<String, ui.Image> _baseShapes = {};

  Future<void> get onReady => ready.future;

  /// generates a 256 color palette used to colorize the heatmap
  _initColorPalette() async {
    List<double> stops = [];
    List<Color> colors = [];

    for (final entry in options.gradient.entries) {
      colors.add(entry.value);
      stops.add(entry.key);
    }

    Gradient colorGradient = LinearGradient(colors: colors, stops: stops);
    var paletteRect = const Rect.fromLTRB(0, 0, 256, 1);

    var shader = colorGradient.createShader(paletteRect,
        textDirection: TextDirection.ltr);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, paletteRect);

    Paint palettePaint = Paint()..shader = shader;
    canvas.drawRect(paletteRect, palettePaint);
    final picture = recorder.endRecording();
    var image = await picture.toImage(256, 1);
    _palette = (await image.toByteData())!;
    ready.complete();
  }

  Future<ui.Image> _getBaseShape() async {
    final radius = math.max(1.0, options.radius);
    final key = '${radius}_${options.blurFactor}';
    if (_baseShapes.containsKey(key)) {
      return _baseShapes[key]!;
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final baseCirclePainter =
        AltBaseCirclePainter(radius: radius, blurFactor: options.blurFactor);
    Size size = Size.fromRadius(radius);
    baseCirclePainter.paint(canvas, size);
    final picture = recorder.endRecording();
    final imgDimension = math.max(1, radius.round()) * 2;
    final image = await picture.toImage(imgDimension, imgDimension);

    _baseShapes[key] = image;
    return image;
  }

  _grayscaleHeatmap(ui.Image baseCircle) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final painter = GrayScaleHeatMapPainter(
        baseCircle: baseCircle, data: data, minOpacity: options.minOpacity);
    painter.paint(
        canvas, Size(width + options.radius, height + options.radius));

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    return image;
  }

  Future<Uint8List> _colorize(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final byteCount = byteData?.lengthInBytes ?? 0;
    var transparentByteCount = 0;
    for (var i = 0, len = byteData!.lengthInBytes, j = 0; i < len; i += 4) {
      final a = byteData.getUint8(i + 3);
      j = a * 4;
      if (j > 0) {
        byteData.setUint8(i, _palette.getUint8(j));
        byteData.setUint8(i + 1, _palette.getUint8(j + 1));
        byteData.setUint8(i + 2, _palette.getUint8(j + 2));
        final palA = _palette.getUint8(j + 3);
        final outA = (a * palA) ~/ 255;
        byteData.setUint8(i + 3, outA);
        if (outA == 0) {
          transparentByteCount += 4;
        }
      } else {
        transparentByteCount += 4;
      }
    }

    Uint8List bitmap;
    // for some reason transparency is not honored when rendering on web. by checking
    // all bytes are transparent we can render a single pixel transparent png instead
    if (transparentByteCount == byteCount) {
      bitmap = kTransparentImage;
    } else {
      bitmap = Bitmap.fromHeadless(
              image.width, image.height, byteData.buffer.asUint8List())
          .buildHeaded();
    }

    return bitmap;
  }

  Future<Uint8List> generate() async {
    await ready.future;

    // if there is no data then return a transparent image
    if (data.isEmpty) {
      return kTransparentImage;
    }
    // generate shape to be used for all points on the heatmap
    final baseShape = await _getBaseShape();

    final grayscale = await _grayscaleHeatmap(baseShape);

    final heatmapBytes = await _colorize(grayscale);

    return heatmapBytes;
  }
}
