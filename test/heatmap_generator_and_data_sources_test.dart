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

    test(
        'generate returns kTransparentImage when every pixel stays transparent',
        () async {
      // Points far outside the canvas: there is data, so this is not the empty-data
      // shortcut, but nothing lands on a pixel — the tile must come back transparent
      // rather than as a bitmap of garbage.
      final heatMap = HeatMap(
        HeatMapOptions(radius: 5.0),
        20,
        20,
        [DataPoint(5000.0, 5000.0, 1.0)],
      );

      expect(await heatMap.generate(), equals(kTransparentImage));
    });

    test('generate reuses the cached base shape on a second run', () async {
      final heatMap = HeatMap(
        HeatMapOptions(radius: 8.0),
        30,
        30,
        [DataPoint(15.0, 15.0, 1.0)],
      );

      final first = await heatMap.generate();
      // Same radius, so the second run takes the cached base circle.
      final second = await heatMap.generate();

      expect(second, equals(first));
    });

    test('onReady completes once the palette is built', () async {
      final heatMap = HeatMap(HeatMapOptions(), 10, 10, [DataPoint(5, 5, 1)]);
      await heatMap.generate();

      await expectLater(heatMap.onReady, completes);
    });
  });

  group('Data Sources', () {
    test('InMemoryHeatMapDataSource returns empty for empty data', () {
      final ds = InMemoryHeatMapDataSource(data: []);
      final bounds = LatLngBounds(const LatLng(0, 0), const LatLng(10, 10));
      expect(ds.getData(bounds, 1), isEmpty);
    });

    test('InMemoryHeatMapDataSource empty data returns empty when overlapping',
        () {
      // The empty-source bounds collapse to (0,0)-(0,0); a viewport that fully
      // contains that point takes the overlapping fast path with empty data.
      final ds = InMemoryHeatMapDataSource(data: []);
      final bounds = LatLngBounds(const LatLng(-1, -1), const LatLng(1, 1));
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

    test('data sources skip a viewport their data cannot reach', () {
      // The source holds one point near the equator; the viewport is on the other side
      // of the world, so both sources short-circuit instead of filtering point by point.
      final faraway = LatLngBounds(const LatLng(60, 60), const LatLng(70, 70));
      final point = WeightedLatLng(const LatLng(1.0, 1.0), 1.0);

      expect(
        InMemoryHeatMapDataSource(data: [point]).getData(faraway, 5),
        isEmpty,
      );
      expect(
        GriddedHeatMapDataSource(data: [point], radius: 20).getData(faraway, 5),
        isEmpty,
      );
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

    test('getImage returns HeatMapImage with appropriate data for coordinates',
        () {
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

    test('HeatMapImage decodes the generated bitmap into a frame', () async {
      final img = HeatMapImage(
        [DataPoint(32.0, 32.0, 1.0)],
        HeatMapOptions(radius: 10.0),
        64,
      );

      final completer = Completer<ImageInfo>();
      img
          .loadImage(
              img, PaintingBinding.instance.instantiateImageCodecWithSize)
          .addListener(
            ImageStreamListener(
              (info, _) => completer.complete(info),
              onError: (error, _) => completer.completeError(error),
            ),
          );

      final info = await completer.future;
      expect(info.image.width, equals(64));
      expect(info.image.height, equals(64));
    });

    test('coincident points both reach the tile at the same pixel', () {
      // Exercises the cell-merge branch of the tile gridding. Note the grid and the
      // localMin/localMax it feeds are discarded — getImage returns one DataPoint per
      // input point — so what is observable is that both points survive and land on
      // the same pixel, not a merged weight.
      final here = WeightedLatLng(const LatLng(0.0, 0.0), 1.0);
      final alsoHere = WeightedLatLng(const LatLng(0.0, 0.0), 4.0);

      final provider = HeatMapTilesProvider(
        dataSource: InMemoryHeatMapDataSource(data: [here, alsoHere]),
        heatMapOptions: HeatMapOptions(radius: 25.0),
      );
      final tileLayer = TileLayer(tileDimension: 256, maxZoom: 18);

      final image = provider.getImage(
        const TileCoordinates(1, 1, 1),
        tileLayer,
      ) as HeatMapImage;

      expect(image.data, hasLength(2));
      expect(image.data[0].x, equals(image.data[1].x));
      expect(image.data[0].y, equals(image.data[1].y));
    });

    test('getImage scales the tile radius with zoom and renders both tiles',
        () async {
      // A single point at (0, 0) sits in the centre tile of every zoom level.
      final point = WeightedLatLng(const LatLng(0.0, 0.0), 1.0);
      final provider = HeatMapTilesProvider(
        dataSource: InMemoryHeatMapDataSource(data: [point]),
        heatMapOptions: HeatMapOptions(radius: 20.0),
      );
      final tileLayer = TileLayer(tileDimension: 256, maxZoom: 18);

      final low = provider.getImage(
        const TileCoordinates(16, 16, 5),
        tileLayer,
      ) as HeatMapImage;
      final high = provider.getImage(
        const TileCoordinates(512, 512, 10),
        tileLayer,
      ) as HeatMapImage;

      // Production scale: radius * zoom / 22 * 1.22 (heat_map_tiles_provider).
      double expectedRadius(int zoom) => 20.0 * zoom / 22 * 1.22;

      expect(low.data, isNotEmpty);
      expect(high.data, isNotEmpty);
      expect(low.generator.options.radius, closeTo(expectedRadius(5), 1e-9));
      expect(high.generator.options.radius, closeTo(expectedRadius(10), 1e-9));
      expect(
        high.generator.options.radius,
        greaterThan(low.generator.options.radius),
      );

      // Existing intensity weighting (intensity / 2^min(maxZoom - zoom, 12)) is
      // preserved; no new intensity-scaling behaviour is introduced here.
      expect(low.data.first.z, closeTo(1 / 4096, 1e-12));
      expect(high.data.first.z, closeTo(1 / 256, 1e-12));

      // Rendering and decoding both resolutions must complete without throwing.
      expect((await _renderFrame(low)).image.width, equals(256));
      expect((await _renderFrame(high)).image.width, equals(256));
    });
  });

  group('HeatMapLayer Widget', () {
    testWidgets(
        'HeatMapLayer renders in FlutterMap and updates on reset stream',
        (tester) async {
      final point = WeightedLatLng(const LatLng(0.0, 0.0), 1.0);
      final ds = InMemoryHeatMapDataSource(data: [point]);
      final resetController = StreamController<void>.broadcast();
      final mapController = MapController();
      addTearDown(mapController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlutterMap(
              mapController: mapController,
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

      // Moving between zoom levels rescales the heatmap tiles; the layer must
      // stay mounted and no rendering exception may surface.
      mapController.move(const LatLng(0, 0), 10);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(HeatMapLayer), findsOneWidget);
      expect(tester.takeException(), isNull);

      mapController.move(const LatLng(0, 0), 5);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(HeatMapLayer), findsOneWidget);
      expect(tester.takeException(), isNull);

      await resetController.close();
    });
  });
}

Future<ImageInfo> _renderFrame(HeatMapImage image) {
  final completer = Completer<ImageInfo>();
  image
      .loadImage(image, PaintingBinding.instance.instantiateImageCodecWithSize)
      .addListener(
        ImageStreamListener(
          (info, _) => completer.complete(info),
          onError: (error, _) => completer.completeError(error),
        ),
      );
  return completer.future;
}
