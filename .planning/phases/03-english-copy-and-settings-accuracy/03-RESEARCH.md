# Phase 3: English Copy and Settings Accuracy - Research

**Researched:** 2026-07-05
**Domain:** Flutter/Dart copy accuracy, Firebase-auth error copy, settings privacy/security wording
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

Source: `.planning/phases/03-english-copy-and-settings-accuracy/03-CONTEXT.md` [VERIFIED: codebase grep]

### Locked Decisions
## Implementation Decisions

### Settings Legal and Privacy Text
- **D-01:** Replace German legal-placeholder settings sections with practical English app information rather than preserving German `Impressum` placeholder content.
- **D-02:** Use plain English labels such as "About", "Privacy", and "Data use" where they fit the existing settings structure.
- **D-03:** Privacy/data-use copy must be conservative and factual: mention Firebase, location use for place discovery, profile/favorites/groups for app features, and external Google Places/Gemini services for place data and summaries where relevant.
- **D-04:** Avoid legal or absolute claims such as "not shared with third parties" unless the implemented app behavior and provider usage truly support them.

### Security Claims
- **D-05:** Replace the current security dialog with security tips only.
- **D-06:** Do not claim end-to-end encryption, regular security updates, two-factor authentication, or other unimplemented protections.
- **D-07:** Keep practical user guidance such as using a strong password, keeping the app updated, and signing out on shared devices.

### Auth Validation and Error Copy
- **D-08:** Login/register validation and Firebase-auth error messages should use plain, actionable English.
- **D-09:** Preferred wording style is short and direct, for example: "Enter your email address", "Use at least 6 characters", "No account found for this email", and "Check your connection and try again."
- **D-10:** Preserve current auth behavior and routing; this phase only changes copy unless a string depends on a false claim.

### the agent's Discretion
- The planner may choose exact English wording as long as it follows the decisions above and stays concise.
- Add lightweight static or widget tests for touched copy surfaces. A static scan for obvious German terms in targeted files is acceptable if widget/provider setup would be disproportionate.

### Deferred Ideas (OUT OF SCOPE)
## Deferred Ideas

- Do not implement new privacy controls, account deletion, password reset, password change, two-factor authentication, or security settings in this phase.
- Profile image actions, cached image placeholders, and visual/theme polish remain Phase 4.
- Group ranking and Borda consensus remain Phase 5.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| REQ-02 | Onboarding text must be in English. | `lib/features/onboarding/ui/onboarding_screen.dart` is already English in the inspected source, so the plan should verify it and avoid unnecessary logic/UI changes. [VERIFIED: codebase grep] |
| REQ-09 | Profile/settings screen must use English copy only. | `lib/features/profile/ui/settings_screen.dart` contains German settings/logout/legal/privacy/security copy and false or over-strong privacy/security claims that should be replaced with factual English app information. [VERIFIED: codebase grep] |
</phase_requirements>

## Project Constraints (from AGENTS.md)

- Stack is Flutter + Dart, Riverpod, GoRouter v17, Firebase Auth + Firestore, Google Places API, and feature-first clean architecture: UI -> Logic/Controller -> Data/Repository. [VERIFIED: AGENTS.md]
- Never mix mock place IDs with real Google Places API IDs. [VERIFIED: AGENTS.md]
- Always use `ref.invalidateSelf()` after state resets. [VERIFIED: AGENTS.md]
- All strings must be English; no German text. [VERIFIED: AGENTS.md]
- Never hardcode API keys; use `flutter_dotenv` and `env.dart`. [VERIFIED: AGENTS.md]
- Empty files named `swipe_card.dart`, `swipe_buttons.dart`, `app_config.dart`, and `env.dart` must be completed before adding new features. [VERIFIED: AGENTS.md]
- Delete unused files only after confirming they are not imported anywhere. [VERIFIED: AGENTS.md]
- After every code change, run `flutter analyze` and fix all errors before continuing. [VERIFIED: AGENTS.md]
- After fixing errors, trigger hot reload via Dart MCP. [VERIFIED: AGENTS.md]
- Do not touch `auth_service.dart`, `firestore_service.dart`, or `group_repository.dart`; only fix the auth redirect bug in `routes.dart` and do not refactor it. [VERIFIED: AGENTS.md]
- `flutter-translator` project skill says German Dart strings should be replaced without logic changes, then `flutter analyze`, hot reload, and screenshot verification should run. [VERIFIED: .agents/skills/flutter-translator/SKILL.md]

## Summary

Phase 3 should be a copy-only cleanup in the UI tier, with one validation task added under `test/`. The current German-copy hits in the requested/touched scope are concentrated in `lib/features/auth/ui/login_screen.dart`, `lib/features/auth/ui/register_screen.dart`, and `lib/features/profile/ui/settings_screen.dart`; `lib/features/onboarding/ui/onboarding_screen.dart` is already English. [VERIFIED: codebase grep]

The settings screen contains the highest-risk copy. It currently presents German placeholder legal identity data, GDPR/legal-style privacy text, a "not shared with third parties" claim, end-to-end encryption, regular security updates, password-change/two-factor future claims, and other security assertions that are not backed by the current implementation. [VERIFIED: codebase grep]

Auth logic should not change. Firebase's Flutter docs show UI code can catch/read `FirebaseAuthException.code`, and the current screens already map error codes locally; this phase should only replace validators and error strings with concise English. [CITED: https://firebase.google.com/docs/auth/flutter/errors] [CITED: https://firebase.google.com/docs/auth/flutter/password-auth]

**Primary recommendation:** Replace copy in auth and settings only, keep navigation/auth/profile logic unchanged, and add a focused static copy regression test for the touched Dart files. [VERIFIED: 03-CONTEXT.md]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| Login/register validation copy | Browser / Client UI | Logic/controller unchanged | The German validation/error strings are in `LoginScreen` and `RegisterScreen`; `AuthController` already delegates auth operations and exposes `AsyncValue` errors. [VERIFIED: codebase grep] |
| Settings labels/dialog copy | Browser / Client UI | API/backend data facts inform wording | `SettingsScreen` owns the displayed legal/privacy/security/logout text; repository/service files only establish what the copy can truthfully claim. [VERIFIED: codebase grep] |
| Privacy/data-use factual basis | API / Backend and external services | Browser / Client UI copy | Firestore user profiles/favorites/groups, Firebase Storage profile images, Google Places, Gemini, and location access are implemented outside the settings UI and should constrain wording. [VERIFIED: codebase grep] |
| German-copy regression coverage | Test tier | Browser / Client UI | Existing tests live under `test/`; Phase 3 should add a copy-focused test file without production logic changes. [VERIFIED: .planning/codebase/TESTING.md] |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Flutter SDK | not on PATH in this shell | UI framework and `flutter test` runner | The project is a Flutter app and `flutter_test` is the existing test framework. [VERIFIED: pubspec.yaml] |
| `flutter_riverpod` | 3.3.1 resolved | UI/provider state access in auth/profile/settings screens | Current screens use Riverpod providers such as `authControllerProvider`. [VERIFIED: pubspec.lock] |
| `go_router` | 17.2.1 resolved | Navigation from auth/settings/onboarding screens | Current screens use `context.go`, and `routes.dart` defines `/settings`, `/login`, `/register`, and `/onboarding`. [VERIFIED: pubspec.lock] |
| `firebase_auth` | 6.1.2 resolved | Email/password auth error source | Current login copy maps `FirebaseAuthException` codes. [VERIFIED: pubspec.lock] |
| `cloud_firestore` | 6.1.0 resolved | User/profile/favorites/groups/place cache persistence | Profile and Places repositories use Firestore collections. [VERIFIED: pubspec.lock] |
| `firebase_storage` | 13.0.4 resolved | Profile image storage capability referenced by truthful privacy copy | `ImageService` uploads profile images to Firebase Storage `profile_images`. [VERIFIED: pubspec.lock] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `flutter_test` | SDK package | Copy regression tests and widget tests | Use for `test()` static scans or `testWidgets()` visible-text assertions. [CITED: https://docs.flutter.dev/cookbook/testing/widget/introduction] |
| `mocktail` | 1.0.5 resolved | Existing mocks for repository tests | Not needed for copy-only tests unless planner adds provider-heavy widget tests. [VERIFIED: pubspec.lock] |
| `fake_cloud_firestore` | 4.1.0+1 resolved | Existing Firestore fakes | Not needed for copy-only tests unless planner tests profile repository facts. [VERIFIED: pubspec.lock] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Static copy scan test | Widget tests for `LoginScreen`, `RegisterScreen`, and `SettingsScreen` | Widget tests verify visible text but need provider setup and dialog pumping; static scans are enough for obvious German-term regressions and are explicitly allowed by phase context. [VERIFIED: 03-CONTEXT.md] |
| Changing auth/profile logic to match copy | Copy-only updates | Logic changes are out of scope unless a string depends on a false claim; current code already supports factual copy. [VERIFIED: 03-CONTEXT.md] |

**Installation:**
```bash
# No new packages should be installed for Phase 3.
```

**Version verification:** Existing dependency versions were read from `pubspec.lock`; no registry install verification is needed because the phase should not add dependencies. [VERIFIED: pubspec.lock]

## Package Legitimacy Audit

No external packages should be installed for this phase, so the package-legitimacy gate is not applicable. [VERIFIED: 03-CONTEXT.md]

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| none | — | — | — | — | — | No install planned |

**Packages removed due to [SLOP] verdict:** none. [VERIFIED: 03-CONTEXT.md]
**Packages flagged as suspicious [SUS]:** none. [VERIFIED: 03-CONTEXT.md]

## Architecture Patterns

### System Architecture Diagram

```text
User opens auth/settings/onboarding screen
  -> Flutter UI widget renders local Text/InputDecoration strings
  -> If auth form is submitted:
       Form validators run locally
       -> AuthController.login/signup keeps existing Firebase flow
       -> FirebaseAuthException.code is mapped to local English message
  -> If settings dialog is opened:
       SettingsScreen renders About / Privacy / Data use / Security tips copy
       -> Copy facts are constrained by Firebase Auth, Firestore, Firebase Storage,
          Google Places, Gemini, location, favorites, and group-session code
  -> Tests:
       Static copy scan over touched Dart files
       -> Optional widget assertions for visible settings/auth text
```

### Recommended Project Structure

```text
lib/
├── features/auth/ui/          # Replace login/register validation and auth error copy
├── features/profile/ui/       # Replace settings/logout/about/privacy/security copy
├── features/onboarding/ui/    # Verify existing English onboarding copy
└── features/*/logic,data/     # Read only for factual claims; avoid logic changes

test/
└── english_copy_regression_test.dart  # Static scan for targeted German/false-claim terms
```

### Pattern 1: Local UI Copy Replacement

**What:** Replace `Text`, `InputDecoration`, validator returns, and local `_getErrorMessage` strings in the owning UI file. [VERIFIED: codebase grep]
**When to use:** Use for `LoginScreen`, `RegisterScreen`, and `SettingsScreen` because the offending copy is local to those widgets. [VERIFIED: codebase grep]
**Example:**
```dart
// Source: current LoginScreen/RegisterScreen local validator pattern.
validator: (value) {
  if (value == null || value.isEmpty) {
    return 'Enter your email address';
  }
  if (!value.contains('@')) {
    return 'Enter a valid email address';
  }
  return null;
}
```

### Pattern 2: Error-Code Mapping Without Logic Changes

**What:** Keep `_getErrorMessage(Object error)` in UI and map Firebase Auth codes to English strings. [CITED: https://firebase.google.com/docs/auth/flutter/errors]
**When to use:** Use when the current screen receives `AsyncValue` errors from `AuthController` and only presentation copy changes. [VERIFIED: codebase grep]
**Example:**
```dart
// Source: Firebase docs expose FirebaseAuthException.code; current UI already uses this shape.
if (error is FirebaseAuthException) {
  switch (error.code) {
    case 'user-not-found':
      return 'No account found for this email';
    case 'wrong-password':
      return 'Incorrect password';
    case 'network-request-failed':
      return 'Check your connection and try again';
  }
}
```

### Pattern 3: Focused Copy Regression Test

**What:** Add a static test that reads the touched Dart files and rejects obvious German terms and removed false-claim phrases. [VERIFIED: 03-CONTEXT.md]
**When to use:** Use because the phase explicitly allows static checks when widget/provider setup would be disproportionate. [VERIFIED: 03-CONTEXT.md]
**Example:**
```dart
// Source: Phase context allows static copy checks; Dart file IO syntax is assumed.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('touched copy surfaces do not contain German or false security claims', () {
    final files = [
      'lib/features/auth/ui/login_screen.dart',
      'lib/features/auth/ui/register_screen.dart',
      'lib/features/profile/ui/settings_screen.dart',
      'lib/features/onboarding/ui/onboarding_screen.dart',
    ];

    final blockedTerms = RegExp(
      r'Bitte|Passwort|Benutzer|Datenschutz|Sicherheit|Impressum|'
      r'Abmelden|Schließen|Ende-zu-Ende|Zwei-Faktor|Dritte',
    );

    for (final path in files) {
      expect(File(path).readAsStringSync(), isNot(contains(blockedTerms)));
    }
  });
}
```

### Anti-Patterns to Avoid

- **Adding privacy/security features to justify copy:** This phase forbids new privacy controls, account deletion, password reset/change, two-factor auth, or security settings. [VERIFIED: 03-CONTEXT.md]
- **Keeping legal boilerplate placeholders:** `Musterfirma GmbH`, `Musterstraße`, `Max Mustermann`, and German `Impressum` placeholder content are not factual app information. [VERIFIED: codebase grep]
- **Making absolute provider/data claims:** The app uses Firebase services and external Google Places/Gemini endpoints, so do not claim data is not shared with third parties. [VERIFIED: codebase grep]
- **Broad route/auth refactors:** `routes.dart` is not a copy owner for this phase and AGENTS says not to refactor it. [VERIFIED: AGENTS.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Auth behavior changes | Custom auth state machine or new password/account flows | Existing `AuthController` and local copy mapping | The requirement is copy accuracy, and Firebase Auth error-code mapping already exists in UI. [VERIFIED: codebase grep] |
| Security/legal compliance claims | DIY legal policy text or invented protections | Conservative app-info copy and security tips only | The current code does not implement E2E encryption, 2FA, password change, or legal compliance workflows. [VERIFIED: codebase grep] |
| Test framework setup | New test runner or dependency | Existing `flutter_test` | `flutter_test` is already configured in `pubspec.yaml` and official docs support `find.text` assertions. [VERIFIED: pubspec.yaml] [CITED: https://docs.flutter.dev/cookbook/testing/widget/finders] |

**Key insight:** The hard part is factual restraint, not implementation complexity; false claims should be removed rather than made true with new features. [VERIFIED: 03-CONTEXT.md]

## Current Copy Findings

### `lib/features/auth/ui/login_screen.dart`

| Lines | Current Issue | Planner Guidance |
|-------|---------------|------------------|
| 65, 68, 80, 83 | German validation messages for email/password fields. [VERIFIED: codebase grep] | Replace with "Enter your email address", "Enter a valid email address", "Enter your password", and "Use at least 6 characters" or similar concise English. [VERIFIED: 03-CONTEXT.md] |
| 135-149 | German Firebase Auth error messages and default `Fehler` prefix. [VERIFIED: codebase grep] | Replace code mappings with actionable English; avoid leaking raw provider messages unless sanitized. [CITED: https://firebase.google.com/docs/auth/flutter/errors] |
| 155-167 | German string-based fallback messages. [VERIFIED: codebase grep] | Mirror the same English copy as FirebaseAuthException mappings. [VERIFIED: codebase grep] |
| 30, 38, 89, 153 | German comments are not user-facing but will fail a broad German-term static scan. [VERIFIED: codebase grep] | Translate comments or scope the static scan to string literals; translating comments is simpler. [ASSUMED] |

### `lib/features/auth/ui/register_screen.dart`

| Lines | Current Issue | Planner Guidance |
|-------|---------------|------------------|
| 46-47 | Name label/hint mixes English and German. [VERIFIED: codebase grep] | Use "Name" or "Display name" and "How should others see your name?" [VERIFIED: 03-CONTEXT.md] |
| 51, 54, 69, 72, 84, 87 | German validation messages. [VERIFIED: codebase grep] | Replace with concise English field requirements. [VERIFIED: 03-CONTEXT.md] |
| 151-159 | German register error mappings. [VERIFIED: codebase grep] | Replace with "This email is already in use", "Enter a valid email address", "Use a stronger password", "Check your connection and try again", and a generic retry fallback. [VERIFIED: 03-CONTEXT.md] |
| 23, 93, 144 | German comments are not user-facing but can trigger broad scans. [VERIFIED: codebase grep] | Translate comments or make the regression regex string-literal aware. [ASSUMED] |

### `lib/features/profile/ui/settings_screen.dart`

| Lines | Current Issue | Planner Guidance |
|-------|---------------|------------------|
| 19, 25-40, 47-48 | Settings list labels/subtitles are German. [VERIFIED: codebase grep] | Use English labels such as "Settings", "About", "Privacy", "Data use", "Security tips", and "Sign out". [VERIFIED: 03-CONTEXT.md] |
| 61-77 | Logout dialog is German. [VERIFIED: codebase grep] | Replace with "Sign out", "Sign out of this device?", "Cancel", and "Sign out". [VERIFIED: 03-CONTEXT.md] |
| 88-131 | `Impressum` dialog contains German legal placeholder identity data. [VERIFIED: codebase grep] | Replace with practical English app information; do not preserve fake company/contact/register details. [VERIFIED: 03-CONTEXT.md] |
| 142-185 | Privacy dialog is German and includes legal/GDPR style claims. [VERIFIED: codebase grep] | Replace with conservative app data-use copy that mentions Firebase, location for discovery, profile/favorites/groups, Google Places, and Gemini where relevant. [VERIFIED: 03-CONTEXT.md] |
| 173 | "not shared with third parties" is too strong because the app uses Firebase, Google Places, Gemini, and profile image storage services. [VERIFIED: codebase grep] | Remove the absolute claim; say services are used to run app features. [VERIFIED: codebase grep] |
| 203-232 | Security dialog claims E2E encryption, Firebase authentication security, HTTPS, regular security updates, and future password-change/2FA availability. [VERIFIED: codebase grep] | Replace with security tips only; keep strong password, app updates, and sign out on shared devices. [VERIFIED: 03-CONTEXT.md] |

### `lib/features/onboarding/ui/onboarding_screen.dart`

| Lines | Current Issue | Planner Guidance |
|-------|---------------|------------------|
| 19-32, 81, 120 | Onboarding user-facing strings are already English. [VERIFIED: codebase grep] | Include in static regression scan but do not edit unless a test reveals drift. [VERIFIED: codebase grep] |

### Other Identified Files

| File | Finding | Planner Guidance |
|------|---------|------------------|
| `lib/features/auth/logic/auth_controller.dart` | No user-facing copy found; it owns auth state and calls repositories. [VERIFIED: codebase grep] | Read-only unless a copy change unexpectedly requires a logic change. [VERIFIED: 03-CONTEXT.md] |
| `lib/features/profile/logic/profile_controller.dart` | No user-facing copy found; it updates profile/favorites/photo URL state. [VERIFIED: codebase grep] | Use only as factual basis for data-use copy. [VERIFIED: codebase grep] |
| `lib/features/profile/data/profile_repository.dart` | Reads/writes `users` documents with email/display name/favorites/groups. [VERIFIED: codebase grep] | Mention profile/favorites/groups data factually if privacy copy lists stored data. [VERIFIED: codebase grep] |
| `lib/features/profile/data/image_service.dart` | Uploads/deletes profile images in Firebase Storage under `profile_images`. [VERIFIED: codebase grep] | Mention profile image storage only if settings copy discusses profile data. [VERIFIED: codebase grep] |
| `lib/core/config/env.dart` | Reads `GOOGLE_PLACES_API_KEY` and `GEMINI_API_KEY` from dotenv. [VERIFIED: codebase grep] | Do not hardcode keys or quote `.env`; use as support for external-service copy. [VERIFIED: AGENTS.md] |
| `lib/core/config/app_config.dart` | `appName` is `Traveller App`; real Places API is enabled by default. [VERIFIED: codebase grep] | Use product naming carefully; `.planning/PROJECT.md` says SwipeTrip is product-facing source of truth while older files still say Traveller App. [VERIFIED: .planning/PROJECT.md] |
| `lib/app/routes.dart` | Defines routes and active-session allowlist; no Phase 3 copy issue found. [VERIFIED: codebase grep] | Do not refactor routes for this phase. [VERIFIED: AGENTS.md] |
| `lib/app/shell_navigation.dart` | Bottom nav labels are already English. [VERIFIED: codebase grep] | No planned change. [VERIFIED: codebase grep] |

## Common Pitfalls

### Pitfall 1: Fixing Copy by Adding Features
**What goes wrong:** The plan adds account deletion, password reset/change, 2FA, privacy controls, or security settings. [VERIFIED: 03-CONTEXT.md]
**Why it happens:** Settings copy currently promises or implies protections/features that do not exist. [VERIFIED: codebase grep]
**How to avoid:** Remove the claim and replace it with factual tips/app info. [VERIFIED: 03-CONTEXT.md]
**Warning signs:** Tasks mention new routes, new repositories, Firebase Auth account-management APIs, or new settings toggles. [VERIFIED: 03-CONTEXT.md]

### Pitfall 2: Over-legalizing the Privacy Dialog
**What goes wrong:** German legal boilerplate is translated into English legal boilerplate rather than replaced with factual app information. [VERIFIED: codebase grep]
**Why it happens:** The existing `Impressum`/privacy dialogs look like policy documents. [VERIFIED: codebase grep]
**How to avoid:** Use short product facts: Firebase account/profile data, location for discovery, favorites/groups for app features, Google Places/Gemini for place data/summaries. [VERIFIED: 03-CONTEXT.md]
**Warning signs:** Copy says "GDPR compliant", "not shared with third parties", "legal rights", or fake company details. [VERIFIED: codebase grep]

### Pitfall 3: Static Test Regex Too Broad or Too Narrow
**What goes wrong:** The scan either fails on harmless technical terms/comments or misses actual visible German strings. [ASSUMED]
**Why it happens:** Current German hits include both `Text(...)`/validator strings and comments. [VERIFIED: codebase grep]
**How to avoid:** Either translate comments too or make the test intentionally scan full files for blocked terms in touched surfaces. [ASSUMED]
**Warning signs:** The test passes while `rg` still finds obvious German UI terms in target files. [VERIFIED: codebase grep]

### Pitfall 4: Verification Toolchain Assumption
**What goes wrong:** The plan assumes `flutter analyze` and `flutter test` can run immediately. [VERIFIED: shell]
**Why it happens:** In this shell, `flutter` and `dart` are not on `PATH`; only `rg` was found. [VERIFIED: shell]
**How to avoid:** Keep commands in the plan but add an environment checkpoint to expose Flutter before final verification. [VERIFIED: shell]
**Warning signs:** `zsh: command not found: flutter` or `zsh: command not found: dart`. [VERIFIED: shell]

## Code Examples

Verified patterns from official sources:

### Widget Copy Assertion

```dart
// Source: https://docs.flutter.dev/cookbook/testing/widget/finders
testWidgets('finds a Text widget', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: Text('Security tips'))),
  );

  expect(find.text('Security tips'), findsOneWidget);
});
```

### Focused Test File Command

```bash
# Source: https://docs.flutter.dev/cookbook/testing/widget/scrolling
flutter test test/english_copy_regression_test.dart
```

### Firebase Auth Error Mapping

```dart
// Source: https://firebase.google.com/docs/auth/flutter/errors
try {
  await FirebaseAuth.instance.signInWithEmailAndPassword(
    email: email,
    password: password,
  );
} on FirebaseAuthException catch (e) {
  final code = e.code;
  // Map code to user-facing English copy in the UI.
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Legal/security boilerplate in settings | Factual app-info copy plus security tips only | Locked by Phase 3 context on 2026-07-05 | Planner should remove false claims instead of implementing features. [VERIFIED: 03-CONTEXT.md] |
| Widget-only copy tests | Static targeted copy scan allowed when widget setup is disproportionate | Locked by Phase 3 context on 2026-07-05 | Planner can add a low-cost regression test without provider-heavy setup. [VERIFIED: 03-CONTEXT.md] |

**Deprecated/outdated:**
- `Impressum` placeholder content: replace with English app information because the placeholder company/person/register data is not factual for the app. [VERIFIED: codebase grep]
- Security-measures checklist: replace with security tips because the current app does not implement the listed protections. [VERIFIED: codebase grep]
- Absolute non-sharing privacy claim: remove because external Firebase/Google services are used by implemented flows. [VERIFIED: codebase grep]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Translating German comments is simpler than making the static regression scan string-literal aware. | Current Copy Findings, Common Pitfalls | Planner may choose a more complex test parser than needed. |
| A2 | A static test using `dart:io` `File(...).readAsStringSync()` is acceptable for this Flutter test suite. | Architecture Patterns | If the test environment disallows file reads, planner should switch to widget tests or a shell-based verification step. |
| A3 | Static-test regex tuning is the main risk for false positives/negatives. | Common Pitfalls | Planner may need to refine blocked terms after first RED/GREEN run. |

## Open Questions

1. **Should the implementation translate German comments too?**
   - What we know: The current German-term scan catches comments in auth files as well as user-facing strings. [VERIFIED: codebase grep]
   - What's unclear: The requirement is user-facing copy, but AGENTS also says all strings/no German text. [VERIFIED: AGENTS.md]
   - Recommendation: Translate comments in touched files to keep the static scan simple and avoid ambiguity. [ASSUMED]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Flutter CLI | `flutter analyze`, `flutter test`, hot reload | ✗ | — | Expose Flutter on PATH before verification. [VERIFIED: shell] |
| Dart CLI | Dart tooling and test runtime | ✗ | — | Usually bundled with Flutter; expose Flutter/Dart toolchain together. [VERIFIED: shell] |
| `rg` | Static discovery/copy scans | ✓ | path found | Use project tests once Flutter is available. [VERIFIED: shell] |
| codebase-memory MCP | Code discovery | ✓ | project indexed with 1984 nodes and 2929 edges | Use `rg` for literal strings when graph search is insufficient. [VERIFIED: codebase-memory-mcp] |
| fast-context MCP | Semantic code discovery | ✗ | blocked by missing Windsurf API key | Use codebase-memory MCP and `rg`. [VERIFIED: fast-context MCP] |

**Missing dependencies with no fallback:**
- Flutter/Dart CLI for final `flutter analyze` and `flutter test` verification. [VERIFIED: shell]

**Missing dependencies with fallback:**
- fast-context semantic search; codebase-memory MCP and `rg` were sufficient for this phase. [VERIFIED: fast-context MCP]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `flutter_test` from Flutter SDK. [VERIFIED: pubspec.yaml] |
| Config file | none detected; existing tests live directly under `test/`. [VERIFIED: .planning/codebase/TESTING.md] |
| Quick run command | `flutter test test/english_copy_regression_test.dart` [CITED: https://docs.flutter.dev/cookbook/testing/widget/scrolling] |
| Full suite command | `flutter test` [VERIFIED: .planning/codebase/TESTING.md] |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| REQ-02 | Onboarding touched surface remains English. | static copy regression | `flutter test test/english_copy_regression_test.dart -x` | ❌ Wave 0 |
| REQ-09 | Settings/auth/profile touched surfaces contain no obvious German terms or removed false security/privacy claims. | static copy regression | `flutter test test/english_copy_regression_test.dart -x` | ❌ Wave 0 |
| REQ-09 | Optional visible settings text appears as English copy after dialog taps. | widget | `flutter test test/settings_copy_test.dart -x` | ❌ Optional |

### Sampling Rate

- **Per task commit:** `flutter analyze && flutter test test/english_copy_regression_test.dart` [VERIFIED: AGENTS.md]
- **Per wave merge:** `flutter analyze && flutter test` [VERIFIED: .planning/codebase/TESTING.md]
- **Phase gate:** Full suite green before `$gsd-verify-work`; if Flutter remains unavailable, record the PATH blocker instead of claiming verification. [VERIFIED: shell]

### Wave 0 Gaps

- [ ] `test/english_copy_regression_test.dart` — covers REQ-02 and REQ-09 static copy scan. [VERIFIED: 03-CONTEXT.md]
- [ ] Flutter/Dart toolchain availability — required before analyzer/tests can run. [VERIFIED: shell]

## Security Domain

Security enforcement is enabled because `.planning/config.json` does not set `security_enforcement` to `false`. [VERIFIED: .planning/config.json]

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Keep Firebase Auth behavior; only rewrite auth error copy. [VERIFIED: codebase grep] |
| V3 Session Management | partial | No session logic change; settings sign-out copy should describe current logout behavior only. [VERIFIED: codebase grep] |
| V4 Access Control | no | Phase has no authorization or access-control implementation change. [VERIFIED: 03-CONTEXT.md] |
| V5 Input Validation | yes | Keep existing form validators and replace validator strings with English. [VERIFIED: codebase grep] |
| V6 Cryptography | yes, for claims | Do not claim end-to-end encryption or cryptographic protections not implemented in code. [VERIFIED: codebase grep] |

OWASP ASVS is a verification standard for testing application security controls, and the official project identifies current ASVS 5.0.0 as the latest stable version. [CITED: https://owasp.org/www-project-application-security-verification-standard/] [CITED: https://github.com/OWASP/ASVS]

### Known Threat Patterns for This Phase

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Misleading security claims | Spoofing / Repudiation | Remove unimplemented claims and use security tips only. [VERIFIED: 03-CONTEXT.md] |
| Overbroad privacy claims | Information Disclosure | State actual data/service use conservatively and avoid absolute non-sharing claims. [VERIFIED: 03-CONTEXT.md] |
| Raw provider error leakage | Information Disclosure | Prefer concise user-safe messages for known auth error codes and a generic fallback. [CITED: https://firebase.google.com/docs/auth/flutter/errors] |

## Sources

### Primary (HIGH confidence)

- `.planning/phases/03-english-copy-and-settings-accuracy/03-CONTEXT.md` — locked decisions, discretion, and deferred scope. [VERIFIED: codebase grep]
- `.planning/ROADMAP.md` — Phase 3 goal and success criteria. [VERIFIED: codebase grep]
- `.planning/REQUIREMENTS.md` — REQ-02 and REQ-09. [VERIFIED: codebase grep]
- `AGENTS.md` — project constraints and do-not-touch rules. [VERIFIED: codebase grep]
- Target source files under `lib/features/auth`, `lib/features/profile`, `lib/features/onboarding`, `lib/app`, and `lib/core/config` — current copy and factual data/service behavior. [VERIFIED: codebase grep]
- `pubspec.yaml` and `pubspec.lock` — existing test/dependency stack. [VERIFIED: codebase grep]

### Secondary (MEDIUM confidence)

- Flutter official docs via Context7: `find.text`, `testWidgets`, focused `flutter test test/widget_test.dart`. [CITED: https://docs.flutter.dev/cookbook/testing/widget/finders]
- Firebase Auth Flutter official docs via Context7: `FirebaseAuthException.code` error handling and email/password sign-in examples. [CITED: https://firebase.google.com/docs/auth/flutter/errors]
- OWASP ASVS official project page and GitHub repo for security-domain framing. [CITED: https://owasp.org/www-project-application-security-verification-standard/]

### Tertiary (LOW confidence)

- Static-test implementation details using direct `dart:io` file reads are assumed from standard Dart practice rather than verified through docs in this session. [ASSUMED]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — versions came from local `pubspec.lock`, and no new packages are recommended. [VERIFIED: pubspec.lock]
- Architecture: HIGH — copy owners and factual data/service boundaries came from local source inspection. [VERIFIED: codebase grep]
- Pitfalls: HIGH for false existing claims, MEDIUM for test-regex implementation details. [VERIFIED: codebase grep] [ASSUMED]

**Research date:** 2026-07-05
**Valid until:** 2026-08-04 for codebase findings, or until touched files change. [ASSUMED]
