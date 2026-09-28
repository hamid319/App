# City Collection Pipeline Design

## Status and scope

This document defines a server-only, deployment-ready city preparation pipeline. It does not connect the Flutter app, migrate `/places`, deploy Firebase resources, create credentials, or write to live services.

The pipeline accepts a Wikidata city QID from an authenticated, App Check-attested user. It prepares an immutable, attributed attraction collection from Wikidata and Wikimedia Commons, stores transformed images in Cloudflare R2, and publishes the collection with one atomic Firestore pointer update. Google Places data remains untouched.

## API contract

All callable functions run in `europe-west1` and require Firebase Authentication and enforced App Check.

- `requestCityCollection({cityQid})` validates `Q[1-9][0-9]*`, applies admission limits, reuses a fresh publication or pending job, and durably records an outbox entry before queue dispatch.
- `getCityPreparation({cityQid})` returns only the requesting user's bounded job view: state, counts, timestamps, and a sanitized failure code.
- `getCityCollection({cityQid, versionId?})` returns at most 50 places from the requested published version. Without `versionId`, it resolves the atomic `publishedVersion` pointer.

No callable returns private candidates, checkpoints, raw upstream responses, credentials, or incremental unpublished places.

## Admission and cost controls

Admission is transactional. An admitted request consumes quota even if its later build fails:

- per user: 2 per UTC day and 10 per UTC month;
- global: 5 per UTC day and 100 per UTC month;
- one active job per city;
- fresh ready publication reuse: 30 days;
- partial or empty retry cooldown: 7 days;
- terminal failure cooldown: 24 hours;
- kill switch and storage pause prevent new admission while existing content remains readable.

Each job is bounded to 150 candidates, 200 Wikimedia metadata HTTP requests, 200 thumbnail attempts, 5 MiB per source image, 300 MiB downloaded per job, 20 minutes per task attempt, three task attempts, and 60 minutes of cumulative task allowance. Download capacity is durably reserved before each request and unused capacity is refunded only after a completed response; an interrupted request keeps its conservative reservation. Queue concurrency and function instances are both one; minimum instances are zero.

These are application safeguards, not a guaranteed euro-denominated cloud bill cap. Operators must also configure billing alerts and monitor Firebase, Cloud Tasks, network, R2, and Artifact Registry usage.

## Source validation

The city QID is resolved server-side. A city qualifies only when it has:

- an allowed settlement instance or a bounded subclass path to settlement;
- a non-empty English label;
- one unambiguous preferred/best-rank coordinate;
- one unambiguous preferred/best-rank country.

Attractions must be within 15 km of that coordinate, in the same country, and belong through a bounded Wikidata subclass path to an explicit allowlist: museum, monument/memorial, historic site/building, religious building, art gallery, park/garden, or viewpoint. Shops, restaurants, cafes, bars, and food businesses are excluded.

At most 150 candidates are ranked deterministically by sitelink count, presence of a P18 image, allowed type priority, distance, and QID.

## Photos and licensing

P18 is the deterministic image seed. Additional images are eligible only when Structured Data on Commons has an exact `depicts` claim for the attraction QID. P373 categories and name-only matches are never accepted automatically.

A place qualifies with one confirmed photo and targets three. Accepted files must:

- be Wikimedia-hosted HTTPS bitmap content;
- have minimum source dimensions of 640 px long edge and 320 px short edge;
- have creator/attribution, source page, exact understood license, and source revision metadata;
- use the conservative v1 allowlist: CC0 1.0, CC BY 4.0, or CC BY-SA 4.0, with matching exact HTTPS license URL and machine-readable short name;
- not be a known map, logo, flag, coat of arms, diagram, or other non-photograph.

Files are deduplicated by Commons page ID and source SHA-1. Downloads reject credentials, non-Wikimedia hosts, unexpected ports, unsafe redirects, bad content types, oversized bodies, and decompression-limit violations. Sharp rotates and emits WebP with a maximum 1280 px long edge. R2 keys are immutable content-addressed keys. Each stored photo retains creator, attribution, license name and URL, Commons file page, original URL, revision, source SHA-1, output SHA-256, dimensions, and modification statement.

## Facts-only descriptions

Descriptions use Wikidata's English short description plus deterministic sentences composed from structured type, city, and country facts. The pipeline does not call an AI service and does not copy Wikipedia or Commons article prose.

## State machine and recovery

Job states are `queued`, `running`, `ready`, `partial`, `empty`, `failed`, and `paused`. Checkpoints record attempt count, cumulative allowance, request/download counters, candidate index, accepted place IDs, and version ID.

Firestore request admission writes the job, active-city lease, and outbox atomically. Dispatch marks the outbox only after enqueue returns. A scheduled recovery function retries pending outbox rows; duplicate tasks are harmless because workers claim and checkpoint idempotently.

Transient 429, 5xx, timeout, and queue failures retry with bounded backoff. Invalid entities, schemas, licenses, media, and insufficient individual candidates are terminal candidate rejections. Exhausted request, download, or storage-import limits are controlled stops: already confirmed places publish as a partial collection, while zero confirmed places produce `empty`. Attempt-time limits checkpoint and retry within the job-wide allowance. Technical failures preserve the old public pointer.

## Publication

Private staging lives under the job. Public data is written to:

`cityCollections/{cityQid}/versions/{versionId}/places/{wd_QID}`

All selected R2 objects are HEAD-verified before public documents are written. After all public documents and version metadata are complete, one Firestore transaction changes `cityCollections/{cityQid}.publishedVersion`. Outcomes are:

- `ready`: exactly 50 places;
- `partial`: 1–49 places;
- `empty`: zero places and no pointer swap.

A failed or empty build preserves the previous publication. Old published versions remain immutable and retained while they fit the 8 GiB storage budget. Automated cleanup may remove abandoned staging objects, but it does not delete a published version or an object referenced by one.

## Verification

Pure tests cover QID/URL/license validation, source normalization, deterministic ranking, 0/1/30/50 publication outcomes, R2 provenance, object verification failure, and idempotent resume. Service tests cover authentication/App Check, quota races, fresh/pending reuse, admitted-failure quota consumption, outbox recovery, and retry exhaustion. Firestore emulator tests use only a demo project ID and confirm that clients cannot read or mutate private pipeline state or write published collections.

Optional operator probes are read-only and bounded. They write reports locally and never publish. Suggested probes are Hamburg, Istanbul, Singapore, Colombo, and New York.

## Primary references

- Firebase task queues: https://firebase.google.com/docs/functions/task-functions
- Firebase function limits: https://firebase.google.com/docs/functions/quotas
- Cloud Tasks delivery: https://cloud.google.com/tasks/docs/dual-overview
- Wikimedia API usage: https://foundation.wikimedia.org/wiki/Policy:Wikimedia_Foundation_API_Usage_Guidelines
- Wikimedia User-Agent policy: https://foundation.wikimedia.org/wiki/Policy:Wikimedia_Foundation_User-Agent_Policy
- Wikidata Query Service limits: https://www.mediawiki.org/wiki/Wikidata_query_service/User_Manual
- Commons machine-readable metadata: https://commons.wikimedia.org/wiki/Help:Machine-readable_data
- Commons reuse guidance: https://commons.wikimedia.org/wiki/Commons:How_to
- Cloudflare R2 pricing: https://developers.cloudflare.com/r2/pricing/
