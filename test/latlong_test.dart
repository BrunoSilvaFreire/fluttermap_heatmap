import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map_heatmap/src/plugin/latlong.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('WeightedLatLng', () {
    test('initialization and properties', () {
      final point = WeightedLatLng(const LatLng(10.0, 20.0), 2.5);
      expect(point.latLng.latitude, equals(10.0));
      expect(point.latLng.longitude, equals(20.0));
      expect(point.intensity, equals(2.5));
    });

    test('toString contains latLng and intensity', () {
      final point = WeightedLatLng(const LatLng(-23.55, -46.63), 1.0);
      final str = point.toString();
      expect(str, contains('WeightedLatLng'));
      expect(str, contains('-23.55'));
      expect(str, contains('-46.63'));
      expect(str, contains('1.0'));
    });

    test('merge recalculates weighted position and sums intensity', () {
      final point = WeightedLatLng(const LatLng(0.0, 0.0), 1.0);
      // Merge with point at lng=10.0, lat=20.0 with intensity=3.0
      point.merge(10.0, 20.0, 3.0);

      // newX = (10.0 * 3 + 0 * 1) / (3 + 1) = 30 / 4 = 7.5
      // newY = (20.0 * 3 + 0 * 1) / (3 + 1) = 60 / 4 = 15.0
      // intensity = 1.0 + 3.0 = 4.0
      expect(point.latLng.longitude, closeTo(7.5, 1e-6));
      expect(point.latLng.latitude, closeTo(15.0, 1e-6));
      expect(point.intensity, closeTo(4.0, 1e-6));
    });
  });
}
