import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';
import 'package:flutter_map_heatmap/src/heatmap/transparent.dart';
import 'package:latlong2/latlong.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HeatMap Generator', () {
    test('generate returns kTransparentImage when data is empty', () async {
      final heatMap = HeatMap(HeatMapOptions(), 100, 100, []);
      final bytes = await heatMap.generate();
      expect(bytes, equals(kTransparentImage));
    });

    test('generate returns valid bitmap bytes when data is provided', () async {
      final heatMap = HeatMap(
        HeatMapOptions(radius: 10.0),
        50,
        50,
        [
          DataPoint(25.0, 25.0, 1.0),
          DataPoint(26.0, 26.0, 2.0),
        ],
      );

      final bytes = await heatMap.generate();
      expect(bytes.isNotEmpty, isTrue);
      // Valid BMP signature
      expect(bytes[0], equals(0x42));
      expect(bytes[1], equals(0x4d));
    });
  });

  group('Data Sources', () {
    test('InMemoryHeatMapDataSource returns empty for empty data', () {
      final ds = InMemoryHeatMapDataSource(data: []);
      final bounds = LatLngBounds(const LatLng(0, 0), const LatLng(10, 10));
      expect(ds.getData(bounds, 1), isEmpty);
    });

    test('InMemoryHeatMapDataSource filters points within bounds', () {
      final p1 = WeightedLatLng(const LatLng(5.0, 5.0), 1.0);
      final p2 = WeightedLatLng(const LatLng(25.0, 25.0), 1.0);

      final ds = InMemoryHeatMapDataSource(data: [p1, p2]);
      final bounds = LatLngBounds(const LatLng(0, 0), const LatLng(10, 10));

      final filtered = ds.getData(bounds, 1);
      expect(filtered.length, equals(1));
      expect(filtered.first, equals(p1));
    });

    test('GriddedHeatMapDataSource returns empty for empty data', () {
      final ds = GriddedHeatMapDataSource(data: [], radius: 20);
      final bounds = LatLngBounds(const LatLng(0, 0), const LatLng(10, 10));
      expect(ds.getData(bounds, 1), isEmpty);
    });

    test('GriddedHeatMapDataSource grids and caches data across calls', () {
      final p1 = WeightedLatLng(const LatLng(1.0, 1.0), 1.0);
      final p2 = WeightedLatLng(const LatLng(1.0001, 1.0001), 2.0);
      final p3 = WeightedLatLng(const LatLng(50.0, 50.0), 1.0);

      final ds = GriddedHeatMapDataSource(data: [p1, p2, p3], radius: 20);
      final bounds = LatLngBounds(const LatLng(0, 0), const LatLng(2, 2));

      final firstCall = ds.getData(bounds, 5.0);
      expect(firstCall.isNotEmpty, isTrue);

      // Second call uses cached grid
      final secondCall = ds.getData(bounds, 5.0);
      expect(secondCall.length, equals(firstCall.length));
    });
  });

  group('HeatMapTilesProvider and HeatMapImage', () {
    test('tile2Lat and tile2Lon conversions', () {
      final ds = InMemoryHeatMapDataSource(data: []);
      final provider = HeatMapTilesProvider(
        dataSource: ds,
        heatMapOptions: HeatMapOptions(),
      );

      final lat = provider.tile2Lat(1, 1);
      expect(lat, inInclusiveRange(-90.0, 90.0));

      final lon = provider.tile2Lon(1, 1);
      expect(lon, inInclusiveRange(-180.0, 180.0));
    });

    test('getImage returns HeatMapImage with appropriate data for coordinates', () {
      final point = WeightedLatLng(const LatLng(0.0, 0.0), 1.0);
      final ds = InMemoryHeatMapDataSource(data: [point]);
      final provider = HeatMapTilesProvider(
        dataSource: ds,
        heatMapOptions: HeatMapOptions(),
      );

      final tileLayer = TileLayer(tileDimension: 256, maxZoom: 18);

      // Zoom level 0 returns empty data
      final img0 = provider.getImage(
        const TileCoordinates(0, 0, 0),
        tileLayer,
      ) as HeatMapImage;
      expect(img0.data, isEmpty);

      // Zoom level 1 containing point
      final img1 = provider.getImage(
        const TileCoordinates(1, 1, 1),
        tileLayer,
      ) as HeatMapImage;
      expect(img1, isNotNull);
      expect(img1.generator.width, equals(256));
    });

    test('HeatMapImage obtainKey returns synchronous future', () async {
      final img = HeatMapImage([], HeatMapOptions(), 256);
      final key = await img.obtainKey(const ImageConfiguration());
      expect(key, equals(img));
    });
  });

  group('HeatMapLayer Widget', () {

    testWidgets('HeatMapLayer renders in FlutterMap and updates on reset stream', (tester) async {
      final point = WeightedLatLng(const LatLng(0.0, 0.0), 1.0);
      final ds = InMemoryHeatMapDataSource(data: [point]);
      final resetController = StreamController<void>.broadcast();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlutterMap(
              options: const MapOptions(
                initialCenter: LatLng(0, 0),
                initialZoom: 5,
              ),
              children: [
                HeatMapLayer(
                  heatMapDataSource: ds,
                  reset: resetController.stream,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(HeatMapLayer), findsOneWidget);

      // Trigger reset stream
      resetController.add(null);
      await tester.pump();

      await resetController.close();
    });
  });
}
