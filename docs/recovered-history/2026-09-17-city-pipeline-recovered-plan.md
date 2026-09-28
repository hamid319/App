# City collection pipeline — recovered plan and stopping point

Recovered on 17 September 2026. This is a reconstruction from the surviving 13 September design specification and a historical summary preserved in Codex's local diagnostic database. It is **not the verbatim Plan mode response**. No application code was changed or deployed during recovery.

## Original conversation

- Thread ID: `01a094e3-b353-74f2-bf80-d309cde50d7e`
- Started: 12 September 2026; historical summary records updates through 13 September at 16:27:34 UTC.
- Original transcript filename: `rollout-2026-09-12T11-12-25-01a094e3-b353-74f2-bf80-d309cde50d7e.jsonl`.
- A surviving diagnostic entry records an archive operation on 15 September at 11:32:03 UTC.
- Current and backup app-state files contain a deleted-thread marker for this ID. This suggests subsequent deletion; it does not establish when or prove whether another copy exists.
- The transcript and its former standalone summary were not found in the checked session/archive directories or history databases.

## Recovered design

1. Prepare reusable city collections on the server, aiming at the user's approximately EUR 50–60/month budget. This was a budget target, not a guaranteed spending cap.
2. Accept a Wikidata city QID through authenticated, App Check-protected Firebase functions. Reuse fresh collections and pending jobs.
3. Find and rank up to 150 Wikidata attraction candidates within 15 km and in the same country. Target up to 50 qualifying places; accept fewer when content is insufficient.
4. Use Wikimedia Commons photographs with confirmed subject identity and acceptable licensing. Require at least one photo per place and target three. Keep attribution and provenance.
5. Generate factual descriptions from structured Wikidata information, without an AI service or copied article prose.
6. Transform photos into immutable WebP assets with Sharp and store them in Cloudflare R2. Store versioned place data in Firestore.
7. Publish only after verifying images and documents, using one atomic published-version pointer update. Preserve the old collection on empty or failed builds.
8. Bound cost and recover failures with quotas, cooldowns, one active job per city, limited concurrency, checkpoints, an outbox, retry limits, a kill switch, and an 8 GiB storage guard.
9. Implement and verify the backend separately. Deployment, credentials, and Flutter integration were outside this implementation scope.

The complete surviving design contract is [the 13 September specification](../superpowers/specs/2026-09-13-city-collection-pipeline-design.md).

## Later implementation findings recovered from the historical summary

These are historical reports, not newly rerun tests or current source verification.

- A Node 22 TypeScript package was implemented under `functions/`.
- Historical verification reported type checking, 14 tests across three files, and two Firestore emulator rules tests passing.
- Oversized Wikidata entity responses and query timeouts led to targeted/batched entity requests and staged nearby retrieval plus classification.
- Read-only probes reportedly resolved Hamburg, Istanbul, Singapore, Colombo, and New York with 69/46/16/22/10 candidates respectively. These were candidate counts, not published photo-qualified collections.
- Full Commons subject matching and thumbnail-host handling remained incomplete or unverified.
- Some real photos used licenses outside the narrow initial allowlist. Whether to support CC BY-SA 2.5/3.0 remained a decision; it was not recorded as approved.
- Three moderate dependency audit findings involving `qs` and nested `uuid` remained.
- Deployment, Flutter integration, real R2 credentials/Firebase Tasks operation, and a full photo-ingestion-to-publication run were not verified.

This explains the remembered partial implementation: backend scaffolding and local tests existed, but live ingestion and app integration were unfinished. The evidence does not establish a precise percentage complete.

## Recovery options without restoring the Mac

| Option | Evidence and prospects |
| --- | --- |
| Recovered summary plus saved specification | Already recovered here. Best available source for reading the plan and stopping point now; not an exact transcript. |
| Recover the single transcript from an older backup | Best remaining route to exact wording if the backup contains it. Search both `.codex/sessions/2026/09/12/` and `.codex/archived_sessions/` for the filename above. Extract to a separate recovery directory. |
| Today's 09:08 local snapshot | A snapshot was listed for 17 September. Contents were not accessed. Useful only if the transcript was present at snapshot time. |
| Another machine or manual `.codex` copy | Can work if that copy predates deletion. No such copy has been located in this investigation. |
| Current archives and app-state backup | Checked. Original transcript absent; app-state `.bak` preserves metadata, not this chat's content. |
| Deleted SQLite records or editor caches | Speculative fallback. Current logical database searches did not recover the transcript. No low-level deleted-page recovery or editor-cache recovery was performed. |

Time Machine supports restoring individual files and folders; a whole-Mac restore is unnecessary. Its normal Restore action returns files to their original location, so avoid overwriting active Codex databases. Apple instructions: https://support.apple.com/en-lamr/guide/mac-help/mh11422/mac

External backup enumeration was blocked by macOS permissions. Git-history inspection was blocked by the unaccepted Xcode license. Neither system setting was changed.

## Evidence

- [Recovered historical summary](2026-09-17-city-pipeline-log-evidence.txt), extracted from `logs_2.sqlite`, log timestamp 15 September 2026, 09:15:50 UTC.
- [Current backend README](../../functions/README.md), describing implementation without deployment or Flutter connection.
- Current and backup `.codex-global-state.json` metadata and read-only session/database searches.
