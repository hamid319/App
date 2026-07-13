class AppConfig {
  static const String appName = 'Traveller App';

  // Cost controls for Google Places API (New)
  // Set to true to allow real HTTP requests to Google APIs.
  static bool enableRealPlacesAPI = true;

  // Absolute max limit of places per city to query or cache.
  static const int maxPlacesLimit = 20;

  // Define other global app configuration constants here
  // e.g., timeouts, max limits, default settings
}
