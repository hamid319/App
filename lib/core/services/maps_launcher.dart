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
