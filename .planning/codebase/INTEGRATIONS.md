# External Integrations

**Analysis Date:** 2026-07-04

## APIs & External Services

**Firebase:**
- Firebase Core - App initialization and platform selection.
  - SDK/Client: `firebase_core`
  - Auth: generated Firebase app options in `lib/firebase_options.dart` and Android client config in `android/app/google-services.json`; API key values are intentionally not copied.
  - Implementation: `lib/main.dart` calls `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`.
- Firebase Authentication - Email/password sign-in, registration, sign-out, and auth state stream.
  - SDK/Client: `firebase_auth`
  - Auth: Firebase project configuration from `lib/firebase_options.dart`
  - Implementation: `lib/core/services/auth_service.dart`, `lib/features/auth/data/auth_repository.dart`, `lib/features/auth/logic/auth_controller.dart`
- Cloud Firestore - Primary app data store for users, groups, sessions, votes, swipes, and places cache.
  - SDK/Client: `cloud_firestore`
  - Auth: Firebase Auth identity and Firestore security rules
  - Implementation: `lib/core/services/firestore_service.dart`, `lib/features/group/data/group_repository.dart`, `lib/features/swipe/data/places_repository.dart`, `lib/features/profile/data/profile_repository.dart`
- Firebase Storage - Profile image object storage.
  - SDK/Client: `firebase_storage`
  - Auth: Firebase Auth identity and Storage security rules
  - Implementation: `lib/features/profile/data/image_service.dart`

**Google Platform:**
- Google Places API (New) Nearby Search - Fetches attractions for a selected city and caches results in Firestore.
  - SDK/Client: `http`
  - Auth: `GOOGLE_PLACES_API_KEY` from `.env` through `Env.googlePlacesApiKey`
  - Endpoint: `https://places.googleapis.com/v1/places:searchNearby`
  - Implementation: `lib/features/swipe/data/places_repository.dart`
- Google Places Photo Media - Builds place photo media URLs from Places API response photo names.
  - SDK/Client: `http` URL construction plus `cached_network_image` rendering
  - Auth: `GOOGLE_PLACES_API_KEY`
  - Endpoint pattern: `https://places.googleapis.com/v1/{photo_name}/media`
  - Implementation: `lib/features/swipe/data/places_repository.dart`
- Google Maps URL launch - Opens coordinates in the external maps app on non-iOS platforms.
  - SDK/Client: `url_launcher`
  - Auth: none
  - Implementation: `lib/core/services/maps_launcher.dart`

**Apple Platform:**
- Apple Maps URL launch - Opens coordinates in Apple Maps on iOS.
  - SDK/Client: `url_launcher`
  - Auth: none
  - Implementation: `lib/core/services/maps_launcher.dart`

**Device Services:**
- Location Services - Requests permission and fetches current high-accuracy position.
  - SDK/Client: `geolocator`
  - Auth: OS-level location permission
  - Implementation: `lib/core/services/location_service.dart`
- Camera and Photo Library - Picks profile images from camera or gallery.
  - SDK/Client: `image_picker`
  - Auth: OS-level camera/photo permissions
  - Implementation: `lib/features/profile/data/image_service.dart`; iOS permission descriptions are in `ios/Runner/Info.plist`.
- Local Preferences - Stores onboarding completion state on-device.
  - SDK/Client: `shared_preferences`
  - Auth: local device storage only
  - Implementation: `lib/core/services/preferences_service.dart`

## Data Storage

**Databases:**
- Cloud Firestore
  - Connection: Firebase options in `lib/firebase_options.dart`; Android generated config in `android/app/google-services.json`
  - Client: `FirebaseFirestore.instance` through `cloud_firestore`
  - Rules: `firestore.rules`
  - Config: `firebase.json`
  - Core wrapper: `lib/core/services/firestore_service.dart`
  - Collections used by code: `users`, `groups`, `places`, `swipeResults`
  - Subcollections used by code: `groups/{groupId}/sessions`, `sessions/{sessionId}/votes`, `sessions/{sessionId}/userSwipes`
  - Transactions and batches: group membership/session/vote operations in `lib/features/group/data/group_repository.dart`; swipe reset batch in `lib/features/swipe/data/places_repository.dart`

**File Storage:**
- Firebase Storage
  - Connection: Firebase options in `lib/firebase_options.dart`
  - Client: `FirebaseStorage.instance` through `firebase_storage`
  - Rules: `storage.rules`
  - Path pattern: `profile_images/profile_{userId}.jpg` in `lib/features/profile/data/image_service.dart`

**Caching:**
- Firestore places cache
  - Collection: `places`
  - Behavior: `PlacesRepository.fetchAndCachePlacesForCity` first queries cached documents by `cityId`; it calls Google Places only when the cache has fewer than the requested limited count.
  - Tests: `test/places_api_migration_test.dart`, `test/places_api_stress_test.dart`
- Image cache
  - Client: `cached_network_image`
  - Usage: `lib/common/widgets/place_card.dart`, `lib/features/swipe/widgets/swipe_card.dart`, and feature screens that render remote place/profile images.
- Local onboarding flag
  - Client: `shared_preferences`
  - Key: `onboarding_shown` in `lib/core/services/preferences_service.dart`

## Authentication & Identity

**Auth Provider:**
- Firebase Authentication
  - Implementation: Custom repository/controller wrapper around Firebase Auth.
  - Service: `lib/core/services/auth_service.dart`
  - Repository: `lib/features/auth/data/auth_repository.dart`
  - Controller: `lib/features/auth/logic/auth_controller.dart`
  - Provider registration: `authServiceProvider` in `lib/main_providers.dart`
  - Supported flows in code: email/password sign-in, email/password registration, sign-out, and auth state stream hydration into `UserModel`
  - Firestore coupling: `AuthController.signup` creates a user profile through `ProfileRepository.createUserProfile` in `lib/features/profile/data/profile_repository.dart`.

## Monitoring & Observability

**Error Tracking:**
- None detected. No Crashlytics, Sentry, or other error tracking dependency is declared in `pubspec.yaml`.

**Logs:**
- Not centralized. Code uses thrown exceptions and Riverpod `AsyncError` states; no logging framework is configured.

## CI/CD & Deployment

**Hosting:**
- Not detected. No deployment workflow, Dockerfile, Codemagic config, or hosting-specific config file was found.

**CI Pipeline:**
- None detected. No `.github/workflows` files were found.

**Firebase Deployment Config:**
- `firebase.json` maps Firestore rules to `firestore.rules`, Firestore indexes to `firestore.indexes.json`, and Storage rules to `storage.rules`.
- `firestore.indexes.json` was referenced by `firebase.json` but not found during this audit.

## Environment Configuration

**Required env vars:**
- `GOOGLE_PLACES_API_KEY` - Used by `Env.googlePlacesApiKey` in `lib/core/config/env.dart` and by `PlacesRepository.fetchAndCachePlacesForCity` in `lib/features/swipe/data/places_repository.dart`.

**Secrets location:**
- `.env` file present - contains environment configuration and is intentionally not read or quoted.
- `.gitignore` ignores `.env` and `.env*`.
- `pubspec.yaml` includes `.env` as a Flutter asset so `flutter_dotenv` can load it at runtime.
- `lib/core/config/env.dart` defines `Env.init()` and `Env.googlePlacesApiKey`; `lib/main.dart` currently initializes Firebase but does not call `Env.init()`.
- Generated Firebase client config exists in `lib/firebase_options.dart` and `android/app/google-services.json`; API key values are intentionally not copied.

## Webhooks & Callbacks

**Incoming:**
- None detected. This is a client Flutter app with no server route or webhook handler code in the repo.

**Outgoing:**
- Google Places API POST requests from `lib/features/swipe/data/places_repository.dart`.
- Google Places photo media URL requests indirectly through image widgets using URLs generated in `lib/features/swipe/data/places_repository.dart`.
- Firebase Auth, Firestore, and Storage client SDK network traffic through Firebase packages.
- External maps launches through `lib/core/services/maps_launcher.dart`.

---

*Integration audit: 2026-07-04*
