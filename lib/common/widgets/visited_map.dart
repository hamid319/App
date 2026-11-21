import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../core/constants/colors.dart';

/// A world map with a glowing orange dot on every city in [cities]
/// (lat, lng). Without cities it shows the plain world.
class VisitedMap extends StatefulWidget {
  const VisitedMap({super.key, required this.cities});

  final List<(double lat, double lng)> cities;

  @override
  State<VisitedMap> createState() => _VisitedMapState();
}

class _VisitedMapState extends State<VisitedMap> {
  MapboxMap? _map;
  CircleAnnotationManager? _dots;

  /// Plain start camera, not a viewport state: that one overrode the fit
  /// in [_draw] when the cities were known before the style had loaded.
  final _start = CameraOptions(
    center: Point(coordinates: Position(10, 25)),
    zoom: 0.8,
  );

  @override
  void didUpdateWidget(VisitedMap old) {
    super.didUpdateWidget(old);
    if (old.cities.length != widget.cities.length) _draw();
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    await map.setCamera(_start);
    await map.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    await map.compass.updateSettings(CompassSettings(enabled: false));
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    final map = _map;
    if (map == null || !mounted) return;
    if (Theme.of(context).brightness == Brightness.dark) {
      await map.setStyleImportConfigProperty('basemap', 'lightPreset', 'night');
    }
    // Grey land and water, so the orange cities stand out at a glance.
    await map.setStyleImportConfigProperty('basemap', 'theme', 'monochrome');
    await map.setStyleImportConfigProperty(
        'basemap', 'showPointOfInterestLabels', false);
    await map.setStyleImportConfigProperty('basemap', 'show3dObjects', false);
    _dots = await map.annotations.createCircleAnnotationManager();
    await _draw();
  }

  Future<void> _draw() async {
    final map = _map, dots = _dots;
    if (map == null || dots == null || !mounted) return;
    await dots.deleteAll();
    final cities = widget.cities;
    if (cities.isEmpty) return;
    final orange = BrandColors.orange.toARGB32();
    final points = [
      for (final (lat, lng) in cities) Point(coordinates: Position(lng, lat)),
    ];
    await dots.createMulti([
      // A soft halo under each dot, so a city reads as lit up.
      for (final p in points)
        CircleAnnotationOptions(
          geometry: p,
          circleColor: orange,
          circleRadius: 22,
          circleBlur: 1,
          circleOpacity: 0.55,
        ),
      for (final p in points)
        CircleAnnotationOptions(
          geometry: p,
          circleColor: orange,
          circleRadius: 7,
          circleStrokeColor: Colors.white.toARGB32(),
          circleStrokeWidth: 2,
        ),
    ]);
    // Never closer than a region: the dot marks a city, not a street.
    final camera = await map.cameraForCoordinatesPadding(
      points,
      CameraOptions(),
      MbxEdgeInsets(top: 80, left: 60, bottom: 80, right: 60),
      4,
      null,
    );
    await map.setCamera(camera);
  }

  @override
  Widget build(BuildContext context) {
    return MapWidget(
      key: const ValueKey('visited-map'),
      styleUri: MapboxStyles.STANDARD,
      onMapCreated: _onMapCreated,
      onStyleLoadedListener: _onStyleLoaded,
    );
  }
}
