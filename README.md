# SwipeTrip

Swipe to discover places, together. SwipeTrip replaces list-and-review trip
planning with a Tinder-style swipe deck: swipe solo to build your favourites,
or start a group session where everyone swipes the same places and the app
surfaces what the group agrees on.

## Stack

Flutter · Riverpod 3 · Firebase (Auth, Firestore, Storage, Functions) ·
GoRouter 17 · Google Places API (New) · Gemini

## Getting started

```bash
# 1. Install Flutter dependencies
flutter pub get

# 2. Create your local environment file
cp .env.example .env
```

`.env` is required for the app to build, because it is declared as a Flutter
asset. It is gitignored and must never contain production keys — see
"API keys" below.

```bash
# 3. Run
flutter run

# 4. Verify
flutter analyze
flutter test
```

## API keys

Google API keys are **not** kept in the app. They live in Secret Manager and
are used only by the Cloud Functions in [`functions/`](functions/README.md),
which fetch places, cache photos into Cloud Storage, and generate place
descriptions. This keeps keys out of the shipped binary and keeps Places API
costs down, since a city is fetched once and shared by every user.

See [`functions/README.md`](functions/README.md) for the deployment steps.

## Project layout

```
lib/
├── app/           GoRouter, shell navigation, theme
├── common/        Models and widgets shared by 2+ features
├── core/          Services, config, constants, errors
├── features/      auth | home | swipe | places | group | profile | onboarding
└── main.dart  main_providers.dart  firebase_options.dart
functions/         Cloud Functions (Places ingestion, photo caching)
```

Each feature follows `ui/` → `logic/` → `data/`: widgets in `ui/`, Riverpod
notifiers in `logic/`, repositories in `data/`. See `CLAUDE.md` for the full
layer rules.

## Deploying backend config

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage,functions
```

Cloud Functions require the Firebase Blaze plan.
