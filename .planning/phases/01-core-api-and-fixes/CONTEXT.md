# Phase 1 Context: Core API and Fixes

## Implementation Decisions

- **Places API Tier**: Google Places API (New) Essentials tier.
- **Description Generation**: Gemini 1.5 Flash generates a 1-sentence description on cache miss.
- **Caching**: Saved to Firestore `/places/{placeId}` using Google Place ID as document ID.
- **API Key**: Managed via `flutter_dotenv` (`.env`) and loaded dynamically at startup via `Env.init()`.
- **Favorites Bug**: Create a separate `addFavoriteById` method in `SwipeController` to avoid advancing the card index.
- **Settings Screen**: Translate all German dialogs and text to English.
- **Firestore Rules**: Match Firestore security rules to model session and vote fields.
