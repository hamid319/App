import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Whether the Google Maps SDK has an API key. On iOS the SDK crashes when
/// a map is created without one, so AppDelegate reports it over a channel
/// (the key comes from the git-ignored ios/Flutter/Secrets.xcconfig).
/// Android shows an empty map instead of crashing and is assumed set up.
class MapsAvailability {
  static const _channel = MethodChannel('swipetrip/maps');

  Future<bool> isConfigured() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return true;
    try {
      return await _channel.invokeMethod<bool>('isConfigured') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
