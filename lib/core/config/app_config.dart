class AppConfig {
  static const String appName = 'TripFam';

  /// Web invite page (Firebase Hosting, web_invite/). Friends open
  /// `$inviteBaseUrl/<CODE>` and join without the app. Switch to the own
  /// domain once it is connected to Hosting.
  static const String inviteBaseUrl = 'https://travelapp-31255.web.app/join';

  // Cost controls for Google Places API (New)
  // Set to true to allow real HTTP requests to Google APIs.
  static bool enableRealPlacesAPI = true;

  // Route place ingestion through the getCityPlaces Cloud Function instead of
  // calling Google directly from the app. The function owns the API keys, so
  // no key ships inside the binary. Set to false only to fall back to the
  // legacy direct-HTTP path for local debugging.
  static const bool usePlacesCloudFunction = true;

  // Region the Cloud Functions are deployed to; must match functions/config.js.
  static const String functionsRegion = 'europe-west1';

  // Firestore's on-device cache (persistence is on by default on mobile).
  // Trips, wishlists, day plans and costs are read from it offline and
  // writes wait in it until the connection is back. 100 MB keeps a few
  // weeks of browsing; the SDK evicts least recently used documents.
  static const int firestoreCacheBytes = 100 * 1024 * 1024;

  // Absolute max limit of places per city to query or cache.
  // Google caps Nearby Search (New) at 20 results per request.
  static const int maxPlacesLimit = 20;

  // Location used when GPS is skipped or fails: Los Angeles, where the
  // current Firestore test places are. Switch to Hamburg (53.5511, 9.9937)
  // once real Places data for Hamburg is loaded.
  static const double defaultLat = 34.0522;
  static const double defaultLng = -118.2437;

  // Development shortcut: skip GPS entirely and always use the default
  // location above. Avoids the permission prompt and the wait for a fix
  // (the simulator has none).
  // TODO(before-launch): set to false. Tracked in POSSIBLE_ERRORS.md 9.1.
  static const bool useFixedDevLocation = true;

  // Development shortcut: when the getCityPlaces Cloud Function is not
  // deployed (or unreachable), build group sessions from places already in
  // Firestore around the group's city instead of failing.
  // TODO(before-launch): set to false. Tracked in POSSIBLE_ERRORS.md 9.2.
  static const bool useDevPlacesFallback = true;

  // Define other global app configuration constants here
  // e.g., timeouts, max limits, default settings
}
