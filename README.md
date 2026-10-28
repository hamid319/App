# TripFam

Plan trips together, then keep them. TripFam is a group-trip app: friends
swipe through places to decide what to do, turn the matches into day plans
on a map, split costs, keep a shared journal with photos, and collect a
passport stamp for every city they travel to.

> The project started as **SwipeTrip**. The Dart package is still called
> `swipetrip` and the Firebase project `travelapp-31255`; everything users
> see says TripFam.

## Features

- **Trips** (`/trips`): create a trip with city and dates, invite friends by
  link or code. Invites open a web page on Firebase Hosting
  (`web_invite/`) that leads into the app.
- **Group swipe** and **wishlist**: everyone swipes the same places; matches
  and ideas land on the trip's wishlist. **Add to trip** from any place.
- **Day plans** on a **Mapbox** map, with walking times between stops.
- **Costs**: shared expenses, who owes whom, edit and delete.
- **Journal**: entries with up to 6 photos per day, and a shareable trip
  recap (stats, collage, map, PNG via the share sheet).
- **TripFam Pass** (profile): a passport-style booklet with a data page, 3D page turns, and a
  stamp per city of trips that have begun.
- **Discover** (`/home`): curated places per city with must-sees, tonight and
  hidden gems; reviews and favourites.
- Works **offline** (Firestore cache, writes sync later), English and German,
  light and dark mode, account deletion in settings.

## Stack

Flutter · Riverpod 3 · GoRouter 17 · Firebase (Auth, Firestore, Storage,
Hosting, Functions) · Mapbox Maps · share_plus · audioplayers

Place data comes from **OpenStreetMap, Wikidata, Wikipedia and Wikimedia
Commons**, collected by `tools/city-import` into Firestore, with photos in
Cloudflare R2. No Google Places content is stored (Google's terms forbid it).

## Getting started

```bash
flutter pub get
cd ios && LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 pod install && cd ..
flutter run
```

Checks before every commit:

```bash
flutter analyze
flutter test
```

### Secrets (not in this repository)

The app builds without them, but maps stay empty. Ask the owner for the
values; never commit them.

| What | Where |
|---|---|
| Mapbox public token (`pk.…`), iOS | `ios/Flutter/Secrets.xcconfig` as `MAPBOX_ACCESS_TOKEN = …` (copy `Secrets.xcconfig.example`) |
| Mapbox public token, Android | `android/local.properties` as `MAPBOX_ACCESS_TOKEN=…` |
| Local dev keys (optional) | `.env` from `.env.example`. Not bundled into the app |
| R2 and Google Cloud access for the city import | `tools/city-import/.env`, see its README |

`lib/firebase_options.dart` is committed; it holds public client config, not
secrets. iOS signing (team and bundle id) is set locally in Xcode and not
committed.

## Project layout

```
lib/
├── app/           GoRouter, shell navigation, theme, account gate, language
├── common/        Models, utils and widgets shared by 2+ features
├── core/          Services, config, constants, errors
├── features/      auth | home | swipe | places | group | profile | onboarding
├── l10n/          app_en.arb, app_de.arb and the generated AppLocalizations
└── main.dart  main_providers.dart  firebase_options.dart
web_invite/        Static invite page on Firebase Hosting (/join/…)
functions/         Cloud Functions
tools/city-import/ Node tool that collects, reviews and publishes city data
firestore.rules  storage.rules  firestore.indexes.json  firebase.json
```

Each feature follows `ui/` → `logic/` → `data/`: widgets in `ui/`, Riverpod
notifiers in `logic/`, repositories in `data/`. The full rules are in
[`CLAUDE.md`](CLAUDE.md).

## Backend

`.firebaserc` pins the project `travelapp-31255` (Blaze plan). The owner
deploys rules, indexes, Storage rules and Hosting:

```bash
firebase deploy --only firestore,storage,hosting
```

## Working on this repository

- **AI agents (Claude and others): read [`CLAUDE.md`](CLAUDE.md) first.** It
  has the architecture rules, the data model, the house rules (line endings,
  files never to commit, who deploys) and the current status.
- Known risks and dev shortcuts to remove before launch:
  [`POSSIBLE_ERRORS.md`](POSSIBLE_ERRORS.md).
- City data pipeline: [`tools/city-import/README.md`](tools/city-import/README.md).
