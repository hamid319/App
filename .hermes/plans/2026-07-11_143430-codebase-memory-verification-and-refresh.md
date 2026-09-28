# Codebase-Memory MCP Verification and Refresh Implementation Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** Keep Hermes connected to the existing SwipeTrip codebase-memory knowledge graph and safely refresh that graph before relying on it for further Flutter/API work.

**Architecture:** Hermes connects to the existing local stdio MCP executable at `/Users/ozanermis/.local/bin/codebase-memory-mcp`. Codex and Hermes have separate client configurations but share the same codebase-memory database and the same indexed SwipeTrip project. Use graph tools for Dart discovery and direct file reads only for literal configuration, Markdown, and generated-file checks.

**Tech Stack:** Hermes Agent native MCP client, codebase-memory-mcp 0.8.1, Flutter/Dart, Riverpod, GoRouter, Firebase, Google Places API New, Gemini API.

---

## Verified Current State

- Hermes MCP server: `codebase-memory`
- Transport: stdio via `/Users/ozanermis/.local/bin/codebase-memory-mcp`
- Hermes connection test: successful; 14 tools discovered.
- Shared indexed project: `Users-ozanermis-Desktop-ProjectP-App-App`
- Project root: `/Users/ozanermis/Desktop/ProjectP/App/App`
- Current graph size: 2,442 nodes and 3,360 edges.
- `detect_changes` reports 86 changed files since the indexed state. The graph should therefore be refreshed before using it as the sole authority for current code behavior.
- This plan intentionally does not commit because the repository already has unrelated tracked and untracked changes.

## Verified Symbol Map

| Concern | Qualified name | File |
|---|---|---|
| Places repository | `Users-ozanermis-Desktop-ProjectP-App-App.lib.features.swipe.data.places_repository.PlacesRepository` | `lib/features/swipe/data/places_repository.dart` |
| Environment initialization | `Users-ozanermis-Desktop-ProjectP-App-App.lib.core.config.env.Env.init` | `lib/core/config/env.dart` |
| Places feature flag owner | `Users-ozanermis-Desktop-ProjectP-App-App.lib.core.config.app_config.AppConfig` | `lib/core/config/app_config.dart` |
| Group vote transaction | `Users-ozanermis-Desktop-ProjectP-App-App.lib.features.group.data.group_repository.GroupRepository.recordSwipeInSession` | `lib/features/group/data/group_repository.dart` |
| Main route/redirect setup | `Users-ozanermis-Desktop-ProjectP-App-App.lib.app.routes.createRouter` | `lib/app/routes.dart` |

## Task 1: Preserve the Current Hermes MCP Configuration

**Objective:** Confirm Hermes retains the existing working MCP connection before working on SwipeTrip.

**Files:**
- Verify: `/Users/ozanermis/.hermes/config.yaml`
- Verify: `/Users/ozanermis/.local/bin/codebase-memory-mcp`

**Step 1: List configured MCP servers**

Run:

```bash
hermes mcp list
```

Expected: `codebase-memory` is enabled and uses `/Users/ozanermis/.local/bin/codebase-memory-mcp`.

**Step 2: Test discovery**

Run:

```bash
hermes mcp test codebase-memory
```

Expected: connection succeeds and discovers 14 tools, including `search_graph`, `trace_path`, `get_code_snippet`, `search_code`, and `detect_changes`.

**Step 3: Restart Hermes before a fresh work session**

Run:

```bash
hermes
```

Expected: MCP tools are available with the `mcp_codebase_memory_*` prefix.

**Step 4: Commit**

Do not commit. MCP configuration is user-level configuration and the project worktree is already dirty.

## Task 2: Refresh the SwipeTrip Knowledge Graph

**Objective:** Replace the stale graph snapshot with an index that includes the 86 detected changed files.

**Files:**
- Read/index: `/Users/ozanermis/Desktop/ProjectP/App/App`
- Optional artifact: `/Users/ozanermis/Desktop/ProjectP/App/App/.codebase-memory/graph.db.zst`

**Step 1: Confirm the index target**

Run:

```bash
/Users/ozanermis/.local/bin/codebase-memory-mcp cli list_projects '{}'
```

Expected: `Users-ozanermis-Desktop-ProjectP-App-App` points to `/Users/ozanermis/Desktop/ProjectP/App/App`.

**Step 2: Run a full index refresh**

Run:

```bash
/Users/ozanermis/.local/bin/codebase-memory-mcp cli index_repository '{"repo_path":"/Users/ozanermis/Desktop/ProjectP/App/App","mode":"full","persistence":true}'
```

Expected: the server reports the project as indexed. Node and edge counts may change.

**Step 3: Confirm no unindexed source changes remain**

Run:

```bash
/Users/ozanermis/.local/bin/codebase-memory-mcp cli detect_changes '{"project":"Users-ozanermis-Desktop-ProjectP-App-App","scope":"working_tree","depth":2}'
```

Expected: no unexpected changed source files are reported relative to the new index. If generated artifacts remain noisy, record that limitation and use Git status plus targeted graph refreshes.

**Step 4: Commit**

Do not commit generated graph artifacts or unrelated project changes unless the user explicitly selects the files to include.

## Task 3: Verify the Critical API and Routing Symbols After Refresh

**Objective:** Prove Hermes is querying the current SwipeTrip graph, not a different project or stale symbol set.

**Files:**
- Verify: `lib/core/config/env.dart`
- Verify: `lib/core/config/app_config.dart`
- Verify: `lib/features/swipe/data/places_repository.dart`
- Verify: `lib/features/group/data/group_repository.dart`
- Verify: `lib/app/routes.dart`

**Step 1: List indexed projects from Hermes**

Prompt Hermes:

```text
Use codebase-memory MCP and list the indexed projects.
```

Expected: the SwipeTrip project appears by its exact project name.

**Step 2: Search the critical symbols**

Prompt Hermes:

```text
Use codebase-memory MCP for project Users-ozanermis-Desktop-ProjectP-App-App. Return qualified names and file paths only for PlacesRepository, Env.init, AppConfig, GroupRepository.recordSwipeInSession, and createRouter.
```

Expected: all five resolve to the files listed in the Verified Symbol Map.

**Step 3: Inspect exact implementation source**

Prompt Hermes:

```text
Use get_code_snippet for Env.init, AppConfig, PlacesRepository.fetchAndCachePlacesForCity, GroupRepository.recordSwipeInSession, and createRouter. Report only concrete runtime preconditions and side effects.
```

Expected: the review confirms dotenv initialization, enabled Places feature gating, cache-first behavior, group transaction behavior, and route redirect behavior from current source.

**Step 4: Trace the group vote transaction**

Prompt Hermes:

```text
Use trace_path for the exact qualified name of GroupRepository.recordSwipeInSession with direction both and depth 3. If the graph has no edges, report that limitation and use search_graph/search_code to locate controller/UI call sites before direct source inspection.
```

Expected: either valid call edges or a documented graph-resolution limitation; do not falsely claim the function has no callers in source code merely because the graph returns none.

## Task 4: Prepare Safe Real-API Verification

**Objective:** Establish an evidence-based preflight before the user adds Gemini Flash and Google Places credentials.

**Files:**
- Verify: `.env` (presence and variable names only; never print secret values)
- Verify: `lib/core/config/env.dart`
- Verify: `lib/core/config/app_config.dart`
- Verify: `lib/main.dart`
- Verify: `lib/features/swipe/data/places_repository.dart`
- Test: `test/places_api_migration_test.dart`
- Test: `test/places_api_stress_test.dart`

**Step 1: Check required environment variable names without exposing values**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
p = Path('.env')
keys = [] if not p.exists() else [line.split('=', 1)[0] for line in p.read_text().splitlines() if '=' in line and not line.lstrip().startswith('#')]
print('GOOGLE_PLACES_API_KEY present:', 'GOOGLE_PLACES_API_KEY' in keys)
print('GEMINI_API_KEY present:', 'GEMINI_API_KEY' in keys)
PY
```

Expected: both variables are present only after the user adds valid credentials.

**Step 2: Verify Flutter static health before live calls**

Run:

```bash
/Users/ozanermis/flutter/bin/flutter pub get
/Users/ozanermis/flutter/bin/flutter analyze
/Users/ozanermis/flutter/bin/flutter test test/places_api_migration_test.dart
/Users/ozanermis/flutter/bin/flutter test test/places_api_stress_test.dart
```

Expected: commands complete successfully before a live API test is considered trustworthy.

**Step 3: Run a controlled live cache-miss verification after credentials are supplied**

Use a development Firebase project and a deliberately uncached test city. Verify:

1. `Env.init()` loads `.env` before repository use.
2. Google Places Nearby Search returns HTTP 200.
3. Firestore receives documents whose IDs are Google Place IDs.
4. Each document contains the expected `cityId`.
5. Gemini success returns a non-empty one-sentence description when enabled.
6. Gemini failure leaves the place usable with a null/empty description rather than failing the whole fetch.

**Step 4: Run a cache-hit verification**

Repeat the same city query and verify that it returns cached Firestore places without a second Google Places request. Record request counts from controlled logging/proxying; do not expose API keys.

**Step 5: Commit**

Only commit test or source changes explicitly selected by the user. Never commit `.env` or credentials.

## Risks and Open Questions

- The graph is confirmed connected but is stale relative to 86 changed files; refresh is required before using graph results for implementation decisions.
- `trace_path` returned no callers/callees for `recordSwipeInSession`, which can indicate incomplete Dart call-edge resolution rather than no real callers. Verify with `search_graph` and source after refresh.
- `AppConfig.enableRealPlacesAPI` is currently `true`; adding a valid Places key can create billable live requests on cache misses.
- Flutter `.env` values are bundled into mobile applications and are not production-grade secret storage. Restrict the Google key by app/bundle identity and API, and use a server-side proxy or Firebase Function before public release.
- Live API validation also depends on Firebase project configuration, Firestore rules, iOS/Android network and app configuration, enabled Google Cloud APIs, billing, and API-key restrictions; valid keys alone cannot prove the entire app works perfectly.
- The exact Gemini endpoint currently targets `gemini-1.5-flash`; availability should be checked against the user’s Google AI/Vertex project before test execution.
