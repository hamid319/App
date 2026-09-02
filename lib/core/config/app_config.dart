class AppConfig {
  static const String appName = 'SwipeTrip';

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

  // Absolute max limit of places per city to query or cache.
  // Google caps Nearby Search (New) at 20 results per request.
  static const int maxPlacesLimit = 20;

  // Define other global app configuration constants here
  // e.g., timeouts, max limits, default settings
}
