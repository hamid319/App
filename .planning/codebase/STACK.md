# Technology Stack

**Analysis Date:** 2026-07-04

## Languages

**Primary:**
- Dart `>=3.0.0 <4.0.0` - Application source under `lib/`, tests under `test/`, and generated Firebase options in `lib/firebase_options.dart`. The resolved lockfile SDK floor is Dart `>=3.12.0 <4.0.0` in `pubspec.lock`.
- Flutter stable - Cross-platform app framework for Android, iOS, macOS, Linux, Windows, and web. Project metadata records Flutter stable revision `19074d12f7eaf6a8180cd4036a430c1d76de904e` in `.metadata`.

**Secondary:**
- Kotlin Gradle DSL - Android build files in `android/settings.gradle.kts`, `android/build.gradle.kts`, and `android/app/build.gradle.kts`.
- Swift - Apple runner code in `ios/Runner/AppDelegate.swift`, `macos/Runner/AppDelegate.swift`, and `macos/Runner/MainFlutterWindow.swift`.
- C++ / CMake - Linux and Windows runner shells in `linux/` and `windows/`.
- Ruby - CocoaPods configuration in `ios/Podfile` and `macos/Podfile`.

## Runtime

**Environment:**
- Flutter SDK - Required by `pubspec.yaml` and platform build files. The local shell used for this audit did not have `flutter` or `dart` on `PATH`, so executable CLI versions were not detected.
- Dart VM / Flutter engine - Used by `lib/main.dart` to initialize Flutter bindings, Firebase, and Riverpod.
- Android JVM toolchain - Java 17 source/target compatibility in `android/app/build.gradle.kts`.
- Gradle `8.14` - Configured by `android/gradle/wrapper/gradle-wrapper.properties`.

**Package Manager:**
- Dart Pub via Flutter - Dependencies declared in `pubspec.yaml`; resolved versions locked in `pubspec.lock`.
- CocoaPods - iOS/macOS plugin locks present in `ios/Podfile.lock` and `macos/Podfile.lock`.
- Gradle Wrapper - Android wrapper files and version config live in `android/gradle/wrapper/`.
- Lockfile: present (`pubspec.lock`, `ios/Podfile.lock`, `macos/Podfile.lock`).

## Frameworks

**Core:**
- Flutter SDK - UI framework, app lifecycle, platform builds, assets, and Material widgets.
- Riverpod `flutter_riverpod 3.3.1`, `riverpod 3.2.1` - Dependency injection and state management. Global providers live in `lib/main_providers.dart`; feature controllers use `AsyncNotifierProvider`, for example `lib/features/auth/logic/auth_controller.dart`.
- GoRouter `17.2.1` - Declarative routing through `routerProvider` in `lib/app/routes.dart` and `MaterialApp.router` in `lib/app/app.dart`.
- Firebase Core `4.2.1` - Initialized in `lib/main.dart` with `DefaultFirebaseOptions.currentPlatform` from `lib/firebase_options.dart`.

**Testing:**
- `flutter_test` - Flutter unit/widget test SDK dependency in `pubspec.yaml`.
- `mocktail 1.0.5` - HTTP client mocking in `test/places_api_migration_test.dart` and `test/places_api_stress_test.dart`.
- `fake_cloud_firestore 4.1.0+1` - Firestore integration-style fakes in Google Places cache tests.

**Build/Dev:**
- `flutter_lints 6.0.0` - Lint baseline included from `analysis_options.yaml`.
- FlutterFire CLI `1.3.2` - Dev dependency for generating Firebase config; output is `lib/firebase_options.dart` and Android config is `android/app/google-services.json`.
- Android Gradle Plugin `8.11.1` - Declared in `android/settings.gradle.kts`.
- Kotlin Android plugin `2.2.20` - Declared in `android/settings.gradle.kts`.
- Google Services Gradle plugin `4.3.15` - Declared in `android/settings.gradle.kts` and applied in `android/app/build.gradle.kts`.

## Key Dependencies

**Critical:**
- `firebase_core 4.2.1` - Bootstraps Firebase using platform options in `lib/firebase_options.dart`.
- `firebase_auth 6.1.2` - Email/password auth in `lib/core/services/auth_service.dart` and `lib/features/auth/data/auth_repository.dart`.
- `cloud_firestore 6.1.0` - Primary cloud database used by `lib/core/services/firestore_service.dart`, `lib/features/group/data/group_repository.dart`, and `lib/features/swipe/data/places_repository.dart`.
- `firebase_storage 13.0.4` - Profile image upload/delete support in `lib/features/profile/data/image_service.dart`.
- `http 1.6.0` - Google Places API HTTP client in `lib/features/swipe/data/places_repository.dart`.
- `flutter_dotenv 6.0.1` - Loads `.env` and exposes `GOOGLE_PLACES_API_KEY` through `lib/core/config/env.dart`.
- `go_router 17.2.1` - App navigation and auth redirect surface in `lib/app/routes.dart`.
- `flutter_riverpod 3.3.1` - Feature controller and service provider layer in `lib/main_providers.dart` and `lib/features/**/logic/`.

**Infrastructure:**
- `geolocator 14.0.2` - Runtime location permission and current-position lookup in `lib/core/services/location_service.dart`.
- `url_launcher 6.3.2` - Opens Google Maps or Apple Maps from `lib/core/services/maps_launcher.dart`.
- `image_picker 1.2.2` - Camera/gallery profile image selection in `lib/features/profile/data/image_service.dart`.
- `shared_preferences 2.5.5` - Local onboarding flag in `lib/core/services/preferences_service.dart`.
- `cached_network_image 3.4.1` - Network image rendering in `lib/common/widgets/place_card.dart`, `lib/features/swipe/widgets/swipe_card.dart`, and several feature screens.
- `material_color_utilities 0.13.0` - Theme generation support referenced by project theme guidance; theme entry point is `lib/app/theme.dart`.
- `meta 1.18.0` - Model annotations in shared model files such as `lib/common/models/user_model.dart`.

## Configuration

**Environment:**
- `.env` file present - contains environment configuration and is intentionally not read or quoted. It is included as a Flutter asset in `pubspec.yaml` and ignored by `.gitignore`.
- `GOOGLE_PLACES_API_KEY` - Expected by `Env.googlePlacesApiKey` in `lib/core/config/env.dart`. Do not hardcode this value in Dart files or docs.
- `Env.init()` loads `.env` in `lib/core/config/env.dart`; `lib/main.dart` currently initializes Firebase but does not call `Env.init()`.
- Firebase project configuration is generated in `lib/firebase_options.dart` and `android/app/google-services.json`. API key values are not copied into this document.
- Google Places real API calls are gated by `AppConfig.enableRealPlacesAPI` and `AppConfig.maxPlacesLimit` in `lib/core/config/app_config.dart`.

**Build:**
- `pubspec.yaml` - App metadata, Dart SDK constraint, dependencies, dev dependencies, Flutter assets.
- `pubspec.lock` - Resolved package versions and SDK floors.
- `analysis_options.yaml` - Flutter lints and build directory exclusion.
- `.metadata` - Flutter project type, stable channel, platform migration metadata.
- `firebase.json` - Firestore rules/indexes, Storage rules, and FlutterFire platform outputs.
- `android/settings.gradle.kts` - Flutter Gradle include, Android/Kotlin/Google Services plugin versions.
- `android/app/build.gradle.kts` - Android namespace, compile/target/min SDK indirection, Java 17 compatibility, debug signing for release.
- `ios/Podfile` and `macos/Podfile` - CocoaPods Flutter plugin setup.
- `web/index.html` and `web/manifest.json` - Flutter web shell and PWA metadata.

## Platform Requirements

**Development:**
- Flutter SDK on `PATH`; required commands include `flutter pub get`, `flutter analyze`, `flutter test`, and platform build commands.
- Java 17 compatible JDK for Android builds based on `android/app/build.gradle.kts`.
- Android SDK/Gradle for Android; `android/local.properties` is intentionally ignored and supplies local Flutter/SDK paths.
- Xcode and CocoaPods for iOS/macOS builds; plugin locks live in `ios/Podfile.lock` and `macos/Podfile.lock`.
- Firebase project access for regenerating `lib/firebase_options.dart` and `android/app/google-services.json` with FlutterFire CLI.
- `.env` with `GOOGLE_PLACES_API_KEY` for real Google Places requests; do not commit this file.

**Production:**
- Deployment target not detected in repo CI/CD files.
- Firebase backend resources are required: Authentication, Cloud Firestore, and Cloud Storage as configured by `firebase.json`, `firestore.rules`, `storage.rules`, and `lib/firebase_options.dart`.
- Google Places API must be enabled for the key referenced by `GOOGLE_PLACES_API_KEY` before enabling real Places calls in `lib/core/config/app_config.dart`.
- Supported generated Flutter platforms: Android, iOS, macOS, Linux, Windows, and web. Firebase options are configured for Android, iOS, macOS, web, and Windows in `lib/firebase_options.dart`; Linux Firebase options are not configured there.

---

*Stack analysis: 2026-07-04*
