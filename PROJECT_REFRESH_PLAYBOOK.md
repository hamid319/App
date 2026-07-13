# SwipeTrip Project Brain Refresh Playbook

## When To Run This

Run this checklist after meaningful changes to:

- architecture or source-of-truth docs
- app startup, routing, auth, onboarding, or provider lifecycle
- Places API/cache behavior
- group sessions, votes, matches, or Firestore data shape
- profile/favorites behavior
- dependencies, generated providers, or test infrastructure

Small isolated copy or styling changes may only need `flutter analyze` and a targeted smoke check.

## 1. Confirm Tooling

Prefer the repo's known Flutter binary if `flutter` is not on `PATH`:

```bash
command -v flutter || true
command -v dart || true
/Users/ozanermis/flutter/bin/flutter --version
```

In this environment, `/Users/ozanermis/flutter/bin/flutter` exists. If a different Flutter install is used, record it in the work notes before claiming verification.

## 2. Verify Flutter Code

For code changes, run:

```bash
/Users/ozanermis/flutter/bin/flutter pub get
/Users/ozanermis/flutter/bin/flutter analyze
```

Run targeted tests for the touched behavior:

```bash
/Users/ozanermis/flutter/bin/flutter test test/places_api_migration_test.dart
/Users/ozanermis/flutter/bin/flutter test test/places_api_stress_test.dart
```

For broad behavior changes, run:

```bash
/Users/ozanermis/flutter/bin/flutter test
```

If a command fails, report the exact failing command and first actionable error. Do not claim the app is clean unless the verification command exits successfully.

## 3. Refresh Project Brain Docs

Update these files when their topic changes:

- `AGENTS.md` for agent workflow or hard coding rules
- `PROJECT_CONTEXT_INDEX.md` for source-of-truth order, feature map, or discovery recipes
- `PROJECT_CORE_IDEA_CANONICAL.md` for product/user-flow changes
- `PROJECT_ARCHITECTURE_CANONICAL.md` for stack, architecture, data model, risks, or recommended fixes
- `PROJECT_LOGIC_MAP.md` for critical flow or invariant changes
- `PROJECT_REFRESH_PLAYBOOK.md` for verification process changes

Keep docs concise. Do not copy every function body into docs; point agents to codebase-memory searches and exact source files.

## 4. Reindex Codebase-Memory

Use codebase-memory MCP from the repo root:

```text
index_repository(repo_path="/Users/ozanermis/Desktop/ProjectP/App/App", mode="full", persistence=true)
```

Then confirm the project is ready:

```text
list_projects()
```

The expected project name is:

```text
Users-ozanermis-Desktop-ProjectP-App-App
```

## 5. Verify Searchability

After reindexing, verify the docs can be found:

```text
search_code(project="Users-ozanermis-Desktop-ProjectP-App-App", pattern="PROJECT_CONTEXT_INDEX", file_pattern="*.md", mode="files")
search_code(project="Users-ozanermis-Desktop-ProjectP-App-App", pattern="group session voting flow|recordSwipeInSession", regex=true, file_pattern="*.md", mode="compact")
search_code(project="Users-ozanermis-Desktop-ProjectP-App-App", pattern="manual process for keeping docs and codebase-memory current", file_pattern="*.md", mode="compact")
search_graph(project="Users-ozanermis-Desktop-ProjectP-App-App", query="critical logic map group session voting")
```

If fresh docs are missing from results, re-run full indexing before rewriting the docs.

## 6. Skill Visibility Check

Flutter/Dart skills currently exist in the repo under `.agents/skills`, and a Claude-only Flutter review skill exists under `.claude/skills`.

Before depending on a skill, verify it is visible to the active runtime. For Codex, do not assume repo-local or Claude-only skills are active unless they appear in the session's available skills list.

If a skill is not visible, use the repo docs, codebase-memory MCP, and direct source inspection instead.

## 7. Final Work Notes

When finishing a task, report:

- files changed
- verification commands run and exit status
- any verification skipped and why
- whether codebase-memory was reindexed
- any docs that may need future refresh
