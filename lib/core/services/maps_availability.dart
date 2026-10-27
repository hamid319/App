import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Whether the Mapbox map has a public access token, and hands it to the
/// SDK. The token comes from the git-ignored ios/Flutter/Secrets.xcconfig
/// (via Info.plist, read by AppDelegate over a channel) or
/// android/local.properties (a string resource the Android SDK reads
/// itself, so Android is assumed set up). Never put the token in Dart code.
class MapsAvailability {
  static const _channel = MethodChannel('swipetrip/maps');

  Future<bool> isConfigured() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return true;
    try {
      final token = await _channel.invokeMethod<String>('accessToken');
      if (token == null || token.isEmpty) return false;
      MapboxOptions.setAccessToken(token);
      return true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
