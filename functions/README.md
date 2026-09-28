# SwipeTrip city collection functions

This isolated Node 22 package prepares attributed city collections from Wikidata and Wikimedia Commons. It is implemented but not deployed or connected to Flutter.

## Local verification

```bash
cd functions
npm ci
npm run typecheck
npm run build
npm test
```

Rules tests must use the emulator and a demo project. Never substitute the live project ID:

```bash
cd functions
JAVA_HOME=/path/to/jdk-21 ../functions/node_modules/.bin/firebase emulators:exec \
  --only firestore --project demo-swipetrip-city-pipeline \
  "npm run test:rules"
```

## Read-only Wikimedia probe

The probe sends the required descriptive User-Agent and writes JSON only to stdout. Its defaults are Hamburg, Istanbul, Singapore, Colombo, and New York. Pass QIDs to narrow it.

```bash
cd functions
npm run probe:wikimedia -- Q1055
```

## Runtime configuration

Deployment is intentionally outside this implementation. Before an approved deployment, provide these through Firebase/Google parameter and secret management:

- secrets: `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`;
- parameters: `R2_ACCOUNT_ID`, `R2_BUCKET`, `R2_PUBLIC_BASE_URL`.

The R2 token must be limited to object read/write for the one pipeline bucket. Do not place any value in Flutter, source control, `.env.example`, or callable payloads.

## Operator controls

`cityPreparationControl/global` supports:

- `killSwitch: true` to refuse new builds while published reads remain available;
- `cumulativeImportedBytes`, maintained transactionally by object reservations;
- operational timestamps/notes if desired.

Use the Firebase console or an audited administrative environment to change the kill switch. There is deliberately no unauthenticated or casual local write script. `scripts/inspect-pipeline.ts` is read-only and requires explicit application-default credentials and `GOOGLE_CLOUD_PROJECT`.

Application limits are cost safeguards, not a guaranteed EUR hard cap. Configure Google Cloud billing alerts/spend controls and Cloudflare notifications separately. Alert on repeated failures, stale running jobs, quota exhaustion, storage approaching 8 GiB, and unexpected task/egress growth.

## Publication and retention

The worker writes immutable `cityCollections/{cityQid}/versions/{versionId}` data and swaps the city pointer only after all selected R2 objects and place documents are verified. Zero-result and technical failures preserve the old pointer. Published versions are retained; only abandoned staging data is eligible for automated cleanup.

