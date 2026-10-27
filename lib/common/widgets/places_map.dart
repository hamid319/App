import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../models/place_model.dart';

/// Places on a Mapbox map (Standard style, night preset in dark mode).
///
/// [numbered] draws numbered pins joined by a route line in list order (a
/// day plan); otherwise plain pins with the place name (favorites). Tapping
/// a pin calls [onTapPlace]. [bottomInset] keeps pins, logo and attribution
/// clear of a sheet that covers the lower part of the map.
class PlacesMap extends StatefulWidget {
  const PlacesMap({
    super.key,
    required this.places,
    this.numbered = false,
    this.bottomInset = 0,
    this.onTapPlace,
  });

  final List<PlaceModel> places;
  final bool numbered;
  final double bottomInset;
  final void Function(PlaceModel place)? onTapPlace;

  @override
  State<PlacesMap> createState() => _PlacesMapState();
}

/// Above this many plain pins the names are left off.
const _maxLabels = 6;

class _PlacesMapState extends State<PlacesMap> {
  MapboxMap? _map;
  PointAnnotationManager? _pins;
  PolylineAnnotationManager? _route;
  Cancelable? _tapSubscription;
  final Map<String, PlaceModel> _byAnnotation = {};

  @override
  void didUpdateWidget(PlacesMap old) {
    super.didUpdateWidget(old);
    final changed = old.numbered != widget.numbered ||
        old.places.length != widget.places.length ||
        !_sameOrder(old.places, widget.places);
    if (changed) _drawPlaces();
  }

  @override
  void dispose() {
    _tapSubscription?.cancel();
    super.dispose();
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    final inset = widget.bottomInset + 8;
    await map.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    await map.compass.updateSettings(CompassSettings(enabled: false));
    // Logo and attribution must stay visible (Mapbox terms): lift them
    // above the sheet instead of hiding them.
    await map.logo.updateSettings(LogoSettings(marginBottom: inset));
    await map.attribution
        .updateSettings(AttributionSettings(marginBottom: inset));
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    final map = _map;
    if (map == null || !mounted) return;
    if (Theme.of(context).brightness == Brightness.dark) {
      await map.setStyleImportConfigProperty('basemap', 'lightPreset', 'night');
    }
    // Our pins are the content; Mapbox's own POI labels only compete.
    await map.setStyleImportConfigProperty(
        'basemap', 'showPointOfInterestLabels', false);
    _route = await map.annotations.createPolylineAnnotationManager();
    _pins = await map.annotations.createPointAnnotationManager();
    _tapSubscription = _pins!.tapEvents(onTap: (annotation) {
      final place = _byAnnotation[annotation.id];
      if (place != null) widget.onTapPlace?.call(place);
    });
    await _drawPlaces();
  }

  Future<void> _drawPlaces() async {
    final map = _map, pins = _pins, route = _route;
    if (map == null || pins == null || route == null || !mounted) return;
    final places = widget.places;
    final scheme = Theme.of(context).colorScheme;
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final dark = Theme.of(context).brightness == Brightness.dark;

    await pins.deleteAll();
    await route.deleteAll();
    _byAnnotation.clear();
    if (places.isEmpty) return;

    if (widget.numbered && places.length > 1) {
      await route.create(PolylineAnnotationOptions(
        geometry:
            LineString(coordinates: [for (final p in places) _position(p)]),
        lineColor: scheme.primary.toARGB32(),
        lineWidth: 4,
        lineOpacity: 0.9,
      ));
    }

    // Names only while they fit; with many pins (favorites in a city) they
    // pile up, and a tap opens the place anyway.
    final labels = !widget.numbered && places.length <= _maxLabels;
    final plainPin =
        widget.numbered ? null : await _pinImage(null, scheme.primary, ratio);
    final lang = mounted ? Localizations.localeOf(context).languageCode : 'en';
    final options = <PointAnnotationOptions>[
      for (final (i, place) in places.indexed)
        PointAnnotationOptions(
          geometry: Point(coordinates: _position(place)),
          image: plainPin ?? await _pinImage(i + 1, scheme.primary, ratio),
          textField: labels ? place.nameFor(lang) : null,
          textSize: 12,
          textOffset: [0, 1.6],
          textAnchor: TextAnchor.TOP,
          textColor: (dark ? Colors.white : Colors.black).toARGB32(),
          textHaloColor: (dark ? Colors.black : Colors.white).toARGB32(),
          textHaloWidth: 1.2,
        ),
    ];
    // One call for all pins: creating them one by one took seconds.
    final created = await pins.createMulti(options);
    for (final (i, annotation) in created.indexed) {
      if (annotation != null) _byAnnotation[annotation.id] = places[i];
    }
    await _fitCamera();
  }

  Future<void> _fitCamera() async {
    final map = _map;
    final places = widget.places;
    if (map == null || places.isEmpty) return;
    if (places.length == 1) {
      await map.setCamera(CameraOptions(
        center: Point(coordinates: _position(places.first)),
        zoom: 15,
        padding: MbxEdgeInsets(
          top: 0,
          left: 0,
          bottom: widget.bottomInset,
          right: 0,
        ),
      ));
      return;
    }
    final camera = await map.cameraForCoordinatesPadding(
      [for (final p in places) Point(coordinates: _position(p))],
      CameraOptions(),
      MbxEdgeInsets(
        top: 96,
        left: 48,
        bottom: widget.bottomInset + 48,
        right: 48,
      ),
      16,
      null,
    );
    await map.setCamera(camera);
  }

  @override
  Widget build(BuildContext context) {
    final center = _center(widget.places);
    return MapWidget(
      key: const ValueKey('places-map'),
      styleUri: MapboxStyles.STANDARD,
      viewport: CameraViewportState(
        center: Point(coordinates: center),
        zoom: widget.places.length > 1 ? 12 : 15,
      ),
      onMapCreated: _onMapCreated,
      onStyleLoadedListener: _onStyleLoaded,
    );
  }
}

Position _position(PlaceModel p) => Position(p.lng, p.lat);

Position _center(List<PlaceModel> places) {
  if (places.isEmpty) return Position(0, 0);
  var south = places.first.lat, north = south;
  var west = places.first.lng, east = west;
  for (final p in places) {
    south = math.min(south, p.lat);
    north = math.max(north, p.lat);
    west = math.min(west, p.lng);
    east = math.max(east, p.lng);
  }
  return Position((west + east) / 2, (south + north) / 2);
}

bool _sameOrder(List<PlaceModel> a, List<PlaceModel> b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i].id != b[i].id) return false;
  }
  return true;
}

/// Tinted disc with a white ring and an optional number, as PNG bytes.
Future<Uint8List> _pinImage(int? number, Color color, double ratio) async {
  final size = number == null ? 24.0 : 34.0;
  final recorder = ui.PictureRecorder();
  final canvas =
      Canvas(recorder, Rect.fromLTWH(0, 0, size * ratio, size * ratio))
        ..scale(ratio);
  final center = Offset(size / 2, size / 2);
  canvas.drawCircle(
    center.translate(0, 1),
    size / 2 - 1,
    Paint()
      ..color = const Color(0x40000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
  );
  canvas.drawCircle(center, size / 2 - 2, Paint()..color = Colors.white);
  canvas.drawCircle(center, size / 2 - 5, Paint()..color = color);
  if (number != null) {
    final painter = TextPainter(
      text: TextSpan(
        text: '$number',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }
  final image = await recorder
      .endRecording()
      .toImage((size * ratio).round(), (size * ratio).round());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}
