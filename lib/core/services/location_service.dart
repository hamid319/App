import 'package:geolocator/geolocator.dart';
import '../config/app_config.dart';

class LocationService {
  Future<bool> requestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
    }
    return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
  }

  Future<Position> getCurrentLocation() async {
    if (AppConfig.useFixedDevLocation) return _defaultPosition();
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('Location services are disabled.');
    await requestPermission();
    return await Geolocator.getCurrentPosition(
      // Without a limit this never returns when the device has no fix (or a
      // simulator has no location set), leaving the swipe deck spinning.
      // Callers fall back to a default location on the timeout.
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
  }

  Position _defaultPosition() => Position(
        latitude: AppConfig.defaultLat,
        longitude: AppConfig.defaultLng,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
}
