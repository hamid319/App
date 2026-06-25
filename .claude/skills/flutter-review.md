---
description: Review changed Dart files against SwipeTrip project rules
---

Run `git diff --name-only HEAD | grep '\.dart$' | grep '^lib/'` to get changed files. Read each file. Check the rules below and output a markdown table.

| File | Line | Rule violated | Severity |
|------|------|---------------|----------|

Rules (HIGH = must fix before merge, LOW = highlight only):

1. [HIGH] German strings must be English — catch: Fehler, Zurück, Überspringen, Einstellungen, Datenschutz, Impressum
2. [HIGH] No hardcoded API keys, secrets, or base URLs — must use `AppConfig` / `dotenv`
3. [HIGH] `Image.network(` must not be used — replace with `CachedNetworkImage(`
4. [HIGH] `swipeControllerProvider.notifier).like()` must NOT be called from `place_detail_screen.dart` — it advances the swipe stack (known bug). Use `addFavoriteById(placeId)` instead
5. [HIGH] Riverpod providers must extend `AsyncNotifier`, `StreamNotifier`, or `Notifier` — no raw `StateNotifier` or manual `setState`
6. [HIGH] No cross-feature imports — `features/A` must not import from `features/B`
7. [LOW] Member UIDs displayed directly in UI — must resolve to `displayName` via Firestore lookup
8. [LOW] `TODO` / `FIXME` comments left in changed files

After the table:
- **PASS** if zero HIGH issues
- **FAIL** if any HIGH issues — list the fix for each
