# SwipeTrip Agent Rules

## Startup Workflow

1. Read `PROJECT_CONTEXT_INDEX.md`.
2. Read `PROJECT_CORE_IDEA_CANONICAL.md` and `PROJECT_ARCHITECTURE_CANONICAL.md`.
3. Before editing critical behavior, read `PROJECT_LOGIC_MAP.md`.
4. Use codebase-memory MCP for code discovery before grep:
   - `search_graph` for functions, classes, providers, and routes.
   - `trace_path` for caller/callee questions when available.
   - `get_code_snippet` for exact symbol source after `search_graph`.
   - `search_code` for strings, config values, docs, and fallback search.
5. After meaningful changes, follow `PROJECT_REFRESH_PLAYBOOK.md`.

## Stack

- Flutter and Dart.
- Riverpod 3 with `AsyncNotifier`, `StreamNotifier`, and generated providers.
- GoRouter 17.
- Firebase Auth, Cloud Firestore, and Firebase Storage.
- Google Places API New Nearby Search.
- Feature-first clean architecture: UI -> Logic/Controller -> Repository/Service.

## Core Rules

- Keep product-facing copy in English unless a full localization system is introduced.
- Never hardcode API keys. Use `.env`, `flutter_dotenv`, and `Env`.
- Never mix mock place IDs with real Google Places IDs in active flows.
- Preserve feature boundaries: UI composes, controllers coordinate state, repositories own data access.
- Use `ref.invalidateSelf()` after provider state resets when the notifier owns reload semantics.
- Treat group session voting and completion as high-risk transaction logic.
- Do not refactor routing, Firestore transactions, or shared models while making unrelated UI changes.
- Delete unused files only after confirming they are not imported anywhere.

## Critical Paths

Read `PROJECT_LOGIC_MAP.md` before changing:

- app bootstrap, `Env`, Firebase initialization, or `main.dart`
- auth, onboarding, or GoRouter redirects
- Places API cache, Google Places IDs, `cityId`, or Firestore place writes
- solo swipe, favorites, place detail, or maps launch behavior
- group creation, invite/join, session start, session voting, completion, or matches
- profile documents, favorites arrays, or profile image storage

## Verification

After code changes:

```bash
/Users/ozanermis/flutter/bin/flutter pub get
/Users/ozanermis/flutter/bin/flutter analyze
/Users/ozanermis/flutter/bin/flutter test
```

If the targeted change is narrow, run the smallest relevant tests first, then `flutter analyze`.
If `flutter` is on `PATH`, the shorter `flutter ...` commands are fine. In this environment, `/Users/ozanermis/flutter/bin/flutter` is known to exist.

After documentation or architecture updates, reindex with codebase-memory MCP and verify the new docs are searchable.

## Optional Local Skills

Repo-local Flutter/Dart skills exist under `.agents/skills`, including Flutter bug fixing, widget tests, routing, HTTP, responsive layout, architecture, and Dart analysis helpers. Use them only when the current agent runtime exposes skills from this repo. Do not assume Claude-only skills under `.claude/skills` are visible to Codex.
