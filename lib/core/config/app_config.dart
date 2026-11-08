class AppConfig {
  static const String appName = 'TripFam';

  /// Web invite page (Firebase Hosting, web_invite/). Friends open
  /// `$inviteBaseUrl/<CODE>` and join without the app. Switch to the own
  /// domain once it is connected to Hosting.
  static const String inviteBaseUrl = 'https://travelapp-31255.web.app/join';

  /// Google Translate's photo mode (menus, labels); the phrasebook adds the
  /// target language as `tl`. On phones it can hand over to the app.
  static const String photoTranslateUrl =
      'https://translate.google.com/?sl=auto&op=images';

  /// Gemini model that reads receipts (Firebase AI Logic, Gemini Developer
  /// API). Flash is cheap: well under a cent per receipt.
  static const String receiptScanModel = 'gemini-2.5-flash';

  /// Receipt scans per user and day, so one account cannot run up costs.
  static const int receiptScansPerDay = 15;

  /// Credit link for places from Overture Maps (place detail sources).
  static const String overtureAttributionUrl =
      'https://docs.overturemaps.org/attribution/';

  // Firestore's on-device cache (persistence is on by default on mobile).
  // Trips, wishlists, day plans and costs are read from it offline and
  // writes wait in it until the connection is back. 100 MB keeps a few
  // weeks of browsing; the SDK evicts least recently used documents.
  static const int firestoreCacheBytes = 100 * 1024 * 1024;

  // Places a trip's pool loads from its city.
  static const int maxPlacesLimit = 20;

  // Places in a trip's group swipe deck: the city's best-known sights.
  static const int groupDeckSize = 60;

  // How close to a trip's city (its centre) a passport check-in counts.
  static const double checkInRadiusKm = 40;

  // Location used when GPS is denied or fails: Berlin, a curated city.
  // Switch to Hamburg (53.5511, 9.9937) once Hamburg is imported.
  static const double defaultLat = 52.5200;
  static const double defaultLng = 13.4050;

  // Development shortcut: skip GPS and always use the default location
  // above (no permission prompt; the simulator has no fix). Must stay false
  // in release builds (POSSIBLE_ERRORS.md 9.1).
  static const bool useFixedDevLocation = false;

  // Define other global app configuration constants here
  // e.g., timeouts, max limits, default settings
}
