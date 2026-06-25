---
description: Check Feature-First Clean Architecture compliance for new/changed files in SwipeTrip
---

Run `git diff --name-only HEAD | grep '^lib/'` to get changed files.

For each file, check its location and class type against these rules:

| File | Class type found | Expected folder | Status |
|---|---|---|---|

Rules:
1. `features/{name}/ui/` — Widget classes and Screen files only. No business logic.
2. `features/{name}/logic/` — Riverpod `AsyncNotifier` / `StreamNotifier` / `Notifier` only. No UI imports.
3. `features/{name}/data/` — Repository classes only. No `BuildContext`, no `ref.watch`.
4. `features/{name}/widgets/` — Reusable widgets scoped to that feature only.
5. `common/models/` — Pure data models (`fromJson`/`toJson`). No feature-specific logic.
6. `common/widgets/` — Truly shared widgets used by 2+ features.
7. `core/services/` — App-wide singleton services (auth, storage, location). No UI.
8. `lib/` root — only `main.dart`, `main_providers.dart`, `firebase_options.dart`. No new files.
9. `app/routes.dart` — all new screens must be registered here. No inline `Navigator.push`.

Also check: if `app/routes.dart` was changed, verify the new route uses the GoRouter `path` convention (lowercase kebab-case, no trailing slash).

Verdict: **PASS** or **FAIL** with the specific rule number violated.
