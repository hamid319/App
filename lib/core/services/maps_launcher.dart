import 'package:url_launcher/url_launcher.dart';

enum MapsApp { apple, google }

/// Opens a route to a place in Apple Maps or Google Maps.
///
/// On iOS the user picks the app (some prefer Google Maps for directions);
/// on Android Google Maps is used directly.
class MapsLauncher {
  /// Apple Maps: route from the current location to the place.
  static Uri appleMapsUri(double lat, double lng, String name) => Uri.https(
        'maps.apple.com',
        '/',
        {'daddr': '$lat,$lng', 'q': name},
      );

  /// Google Maps iOS app (needs `comgooglemaps` in LSApplicationQueriesSchemes).
  static Uri googleMapsAppUri(double lat, double lng) => Uri(
        scheme: 'comgooglemaps',
        queryParameters: {'daddr': '$lat,$lng'},
      );

  /// Google Maps on the web; Android and iOS hand it to the app if installed.
  static Uri googleMapsWebUri(double lat, double lng) => Uri.https(
        'www.google.com',
        '/maps/dir/',
        {'api': '1', 'destination': '$lat,$lng'},
      );

  /// Most stops a Google Maps route URL takes (origin, 8 waypoints,
  /// destination).
  static const maxRouteStops = 10;

  /// Walking route through [stops] in Google Maps; the app opens it when
  /// installed. Stops beyond [maxRouteStops] are left out.
  static Uri googleMapsRouteUri(List<({double lat, double lng})> stops) {
    final shown = stops.take(maxRouteStops).toList();
    String point(({double lat, double lng}) p) => '${p.lat},${p.lng}';
    return Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'origin': point(shown.first),
      'destination': point(shown.last),
      if (shown.length > 2)
        'waypoints': shown.sublist(1, shown.length - 1).map(point).join('|'),
      'travelmode': 'walking',
    });
  }

  static Future<void> openRoute(List<({double lat, double lng})> stops) async {
    if (stops.isEmpty) return;
    if (!await _launch(googleMapsRouteUri(stops))) {
      throw Exception('Could not launch maps');
    }
  }

  static Future<void> open(
    MapsApp app,
    double lat,
    double lng,
    String name,
  ) async {
    final bool opened;
    switch (app) {
      case MapsApp.apple:
        opened = await _launch(appleMapsUri(lat, lng, name));
      case MapsApp.google:
        final appUri = googleMapsAppUri(lat, lng);
        opened = await canLaunchUrl(appUri)
            ? await _launch(appUri)
            : await _launch(googleMapsWebUri(lat, lng));
    }
    if (!opened) throw Exception('Could not launch maps');
  }

  static Future<bool> _launch(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
}
