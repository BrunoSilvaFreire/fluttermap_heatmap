import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('HeatMapLayer Widget and Map Integration', () {
    testWidgets('mounts HeatMapLayer in FlutterMap and renders tiles without error', (tester) async {
      final resetController = StreamController<void>.broadcast();
      addTearDown(resetController.close);

      final points = [
        WeightedLatLng(const LatLng(-25.4284, -49.2733), 1.0),
        WeightedLatLng(const LatLng(-25.4300, -49.2700), 2.5),
        WeightedLatLng(const LatLng(-25.4250, -49.2750), 0.8),
      ];

      final dataSource = InMemoryHeatMapDataSource(data: points);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: FlutterMap(
                options: const MapOptions(
                  initialCenter: LatLng(-25.4284, -49.2733),
                  initialZoom: 12.0,
                ),
                children: [
                  HeatMapLayer(
                    key: const ValueKey('heatmap_test_layer'),
                    heatMapDataSource: dataSource,
                    heatMapOptions: HeatMapOptions(
                      radius: 35.0,
                      minOpacity: 0.1,
                      blurFactor: 0.6,
                    ),
                    reset: resetController.stream,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Verify HeatMapLayer is present in widget tree
      expect(find.byKey(const ValueKey('heatmap_test_layer')), findsOneWidget);
      expect(find.byType(TileLayer), findsOneWidget);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Trigger reset stream to test dynamic tile layer reload
      resetController.add(null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const ValueKey('heatmap_test_layer')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
