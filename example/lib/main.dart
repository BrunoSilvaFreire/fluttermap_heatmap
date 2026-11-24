import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';
import 'package:latlong2/latlong.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Heatmap Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MyHomePage(title: 'flutter_mapmap heat_map demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final StreamController<void> _rebuildStream = StreamController.broadcast();
  List<WeightedLatLng> data = [];
  List<Map<double, Color>> gradients = [
    HeatMapOptions.defaultGradient,
    {0.25: Colors.blue, 0.55: Colors.red, 0.85: Colors.pink, 1.0: Colors.purple}
  ];

  var index = 0;

  @override
  initState() {
    _loadData();
    super.initState();
  }

  @override
  dispose() {
    _rebuildStream.close();
    super.dispose();
  }

  _loadData() async {
    var str = await rootBundle.loadString('assets/initial_data.json');
    List<dynamic> result = jsonDecode(str);

    setState(() {
      data = result
          .map((e) => e as List<dynamic>)
          .map((e) => WeightedLatLng(LatLng(e[0], e[1]), 1))
          .toList();
    });
  }

  void _incrementCounter() {
    setState(() {
      index = index == 0 ? 1 : 0;
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        _rebuildStream.add(null);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _rebuildStream.add(null);
    });

    final map = FlutterMap(
      options: const MapOptions(
        backgroundColor: Colors.transparent,
        initialCenter: LatLng(57.8827, -6.0400),
        initialZoom: 8.0,
      ),
      children: [
        TileLayer(
            urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png"),
        if (data.isNotEmpty)
          HeatMapLayer(
            heatMapDataSource: InMemoryHeatMapDataSource(data: data),
            heatMapOptions:
                HeatMapOptions(gradient: gradients[index], minOpacity: 0.1),
            reset: _rebuildStream.stream,
          )
      ],
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      backgroundColor: Colors.pink,
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Container(child: map),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Switch Gradient',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
