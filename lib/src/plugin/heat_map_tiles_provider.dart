import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:latlong2/latlong.dart';

class HeatMapTilesProvider extends TileProvider {
  HeatMapDataSource dataSource;
  HeatMapOptions heatMapOptions;

  late Map<double, List<DataPoint>> griddedData;

  HeatMapTilesProvider(
      {required this.dataSource, required this.heatMapOptions});

  double _calculateRadius(TileCoordinates coords) {
    if (heatMapOptions.worldSpace) {
      final centerLat = tile2Lat(coords.y + 0.5, coords.z);
      final centerLon = tile2Lon(coords.x + 0.5, coords.z);
      final center = LatLng(centerLat, centerLon);
      final edge = const Distance().offset(center, heatMapOptions.radius, 90);
      const crs = Epsg3857();
      final pCenter = crs.latLngToOffset(center, coords.z.toDouble());
      final pEdge = crs.latLngToOffset(edge, coords.z.toDouble());
      return math.max(1.0, (pEdge.dx - pCenter.dx).abs());
    } else {
      var scale = coords.z / 22 * 1.22;
      return math.max(1.0, heatMapOptions.radius * scale);
    }
  }

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    var tileSize = options.tileDimension;

    // disable zoom level 0 for now. ned to refactor _filterData
    List<DataPoint> filteredData =
        coordinates.z != 0 ? _filterData(coordinates, options) : [];
    final radius = _calculateRadius(coordinates);
    var imageHMOptions = HeatMapOptions(
      radius: radius,
      minOpacity: heatMapOptions.minOpacity,
      gradient: heatMapOptions.gradient,
      blurFactor: heatMapOptions.blurFactor,
      layerOpacity: heatMapOptions.layerOpacity,
      worldSpace: heatMapOptions.worldSpace,
    );
    return HeatMapImage(filteredData, imageHMOptions, tileSize);
  }

  /// hyperbolic sine implementation
  static double _sinh(double angle) {
    return (math.exp(angle) - math.exp(-angle)) / 2;
  }

  _filterData(TileCoordinates coords, TileLayer options) {
    List<DataPoint> filteredData = [];
    final zoom = coords.z;
    final tileRadius = _calculateRadius(coords);
    var size = options.tileDimension;
    final buffer = math.max(1.0, (tileRadius / options.tileDimension).ceilToDouble());
    final bounds = _bounds(coords, buffer);
    final points = dataSource.getData(bounds, zoom.toDouble());

    final cellSize = math.max(1.0, tileRadius / 2);

    final gridOffset = size;
    final gridSize = size + gridOffset;

    var gridLength = (gridSize / cellSize).ceil() + 2 + gridOffset.ceil();
    List<List<DataPoint?>> grid =
        List<List<DataPoint?>>.filled(gridLength, [], growable: true);

    const crs = Epsg3857();

    var localMin = 0.0;
    var localMax = 0.0;
    Offset tileOffset =
        Offset(options.tileDimension.toDouble() * coords.x, options.tileDimension.toDouble() * coords.y,);
    for (final point in points) {
      if (bounds.contains(point.latLng)) {
        var pixel =
            crs.latLngToOffset(point.latLng, zoom.toDouble()) - tileOffset;

        final x = ((pixel.dx) ~/ cellSize) + 2 + gridOffset.ceil();
        final y = ((pixel.dy) ~/ cellSize) + 2 + gridOffset.ceil();

        // The heat map tool emits intensities already normalized to [0, 1], so
        // they are painted as-is; no zoom attenuation is applied.
        final k = point.intensity;

        if (y >= 0 && y < grid.length) {
          final targetLen = (gridSize / cellSize).ceil() + 2 + gridOffset.ceil();
          if (grid[y].length < targetLen) {
            grid[y] = List<DataPoint?>.filled(targetLen, null, growable: true);
          }
          if (x >= 0 && x < grid[y].length) {
            var cell = grid[y][x];
            if (cell == null) {
              grid[y][x] = DataPoint(pixel.dx, pixel.dy, k);
              cell = grid[y][x];
            } else {
              cell.merge(pixel.dx, pixel.dy, k);
            }
            localMax = math.max(cell!.z, localMax);
            localMin = math.min(cell.z, localMin);
          }
        }

        if (bounds.contains(point.latLng)) {
          filteredData.add(DataPoint(pixel.dx, pixel.dy, k));
        }
      }
    }

    return filteredData;
  }

  /// extract bounds from tile coordinates. An optional [buffer] can be passed to expand the bounds
  /// to include a buffer. eg. a buffer of 0.5 would add a half tile buffer to all sides of the bounds.
  LatLngBounds _bounds(TileCoordinates coords, [double buffer = 0]) {
    var sw = LatLng(tile2Lat(coords.y + 1 + buffer, coords.z),
        tile2Lon(coords.x - buffer, coords.z));
    var ne = LatLng(tile2Lat(coords.y - buffer, coords.z),
        tile2Lon(coords.x + 1 + buffer, coords.z));
    return LatLngBounds(sw, ne);
  }

  /// converts tile y to latitude. if the latitude is out of range it is adjusted to the min/max
  /// latitude (-90,90)
  double tile2Lat(num y, num z) {
    var yBounded = math.max(y, 0);
    var n = math.pow(2.0, z);
    var latRad = math.atan(_sinh(math.pi * (1 - 2 * yBounded / n)));
    var latDeg = latRad * 180 / math.pi;
    //keep the point in the world
    return latDeg > 0
        ? math.min(latDeg, 90).toDouble()
        : math.max(latDeg, -90).toDouble();
  }

  /// converts the tile x to longitude. if the longitude is out of range then it is adjusted to the
  /// min/max longitude (-180/180)
  double tile2Lon(num x, num z) {
    var xBounded = math.max(x, 0);
    var lonDeg = xBounded / math.pow(2.0, z) * 360 - 180;
    return lonDeg > 0
        ? math.min(lonDeg, 180).toDouble()
        : math.max(lonDeg, -180).toDouble();
  }
}

class HeatMapImage extends ImageProvider<HeatMapImage> {
  final List<DataPoint> data;
  final HeatMap generator;

  HeatMapImage(this.data, HeatMapOptions heatmapOptions, int size)
      : generator = HeatMap(heatmapOptions, size, size, data);

  @override
  ImageStreamCompleter loadImage(HeatMapImage key, decode) {
    return MultiFrameImageStreamCompleter(codec: _generate(), scale: 1);
  }

  Future<ui.Codec> _generate() async {
    var bytes = await generator.generate();
    var buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    return PaintingBinding.instance.instantiateImageCodecWithSize(buffer);
  }

  @override
  Future<HeatMapImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }
}
