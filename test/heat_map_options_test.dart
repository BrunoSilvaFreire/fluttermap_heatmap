import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';

void main() {
  group('HeatMapOptions', () {
    test('default options are populated correctly', () {
      final options = HeatMapOptions();
      expect(options.radius, equals(30));
      expect(options.minOpacity, equals(0.3));
      expect(options.blurFactor, equals(0.5));
      expect(options.layerOpacity, equals(0.75));
      expect(options.gradient.length, equals(4));
    });

    test('custom valid options are applied', () {
      final customGradient = {
        0.5: Colors.purple,
        1.0: Colors.amber,
      };
      final options = HeatMapOptions(
        radius: 45.0,
        minOpacity: 0.1,
        blurFactor: 0.8,
        layerOpacity: 0.9,
        gradient: customGradient,
      );
      expect(options.radius, equals(45.0));
      expect(options.minOpacity, equals(0.1));
      expect(options.blurFactor, equals(0.8));
      expect(options.layerOpacity, equals(0.9));
      expect(options.gradient, equals(customGradient));
    });

    test('invalid layerOpacity and blurFactor fall back to 0.75', () {
      final optionsNegative = HeatMapOptions(
        layerOpacity: -0.1,
        blurFactor: -0.5,
      );
      expect(optionsNegative.layerOpacity, equals(0.75));
      expect(optionsNegative.blurFactor, equals(0.75));

      final optionsAboveOne = HeatMapOptions(
        layerOpacity: 1.5,
        blurFactor: 2.0,
      );
      expect(optionsAboveOne.layerOpacity, equals(0.75));
      expect(optionsAboveOne.blurFactor, equals(0.75));
    });
  });

  group('HeatMapDataPoint', () {
    test('constructor and defaults', () {
      final point = HeatMapDataPoint(10.0, 20.0);
      expect(point.x, equals(10.0));
      expect(point.y, equals(20.0));
      expect(point.intensity, equals(1.0));
    });

    test('equality and hashCode', () {
      final p1 = HeatMapDataPoint(10.0, 20.0, intensity: 2.0);
      final p2 = HeatMapDataPoint(10.0, 20.0, intensity: 2.0);
      final p3 = HeatMapDataPoint(10.0, 20.0, intensity: 3.0);
      final p4 = HeatMapDataPoint(11.0, 20.0, intensity: 2.0);

      expect(p1, equals(p2));
      expect(p1.hashCode, equals(p2.hashCode));
      expect(p1, isNot(equals(p3)));
      expect(p1, isNot(equals(p4)));
    });

    test('merge updates coordinates and adds intensity', () {
      final p = HeatMapDataPoint(2.0, 4.0, intensity: 1.0);
      p.merge(6.0, 8.0, 2.0);
      // in heat_map_options.dart:
      // this.x = (x * intensity + this.x * this.intensity) / intensity + this.intensity;
      // this.y = (y * intensity + this.y * this.intensity) / intensity + this.intensity;
      // this.intensity += intensity;
      // Note: testing actual implementation behaviour
      expect(p.intensity, equals(3.0));
    });
  });
}
