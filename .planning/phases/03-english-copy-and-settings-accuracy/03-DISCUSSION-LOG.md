# Phase 3: English Copy and Settings Accuracy - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-05T12:53:56Z
**Phase:** 3-English Copy and Settings Accuracy
**Areas discussed:** Settings legal/privacy text, Security claims, Auth validation/error copy

---

## Area Selection

| Option | Description | Selected |
|--------|-------------|----------|
| All three | Discuss settings legal/privacy text, security claims, and auth error copy so the planner has complete decisions. | ✓ |
| Settings only | Focus on settings legal/privacy/security copy; auth error text can follow the obvious English translation path. | |
| Auth only | Focus on login/register validation and Firebase error wording; settings can follow conservative placeholder cleanup. | |

**User's choice:** All three
**Notes:** Phase 3 should capture complete copy/settings decisions before planning.

---

## Settings Legal and Privacy Text

| Option | Description | Selected |
|--------|-------------|----------|
| Practical app info | Replace legal placeholders with plain English "About", "Privacy", and "Data use" copy that accurately describes current app behavior. | ✓ |
| Minimal placeholders | Translate to English but keep placeholder-style legal sections for later replacement. | |
| Remove legal dialogs | Remove Impressum/privacy-style dialogs for now and keep only settings items that reflect implemented app features. | |

**User's choice:** Practical app info
**Notes:** Planner should remove German legal placeholder feel and replace it with accurate app information.

### Privacy/Data Use Detail

| Option | Description | Selected |
|--------|-------------|----------|
| Conservative factual | Mention Firebase, location, profile/favorites/groups, Google Places, and Gemini where relevant; avoid absolute legal promises. | ✓ |
| User-friendly short | Keep it brief with less detail about providers. | |
| Detailed disclosure | Include longer provider-by-provider explanation. | |

**User's choice:** Conservative factual
**Notes:** Avoid claims like "not shared with third parties."

---

## Security Claims

| Option | Description | Selected |
|--------|-------------|----------|
| Current protections only | Say the app uses Firebase Authentication and HTTPS-backed service connections, and advise strong passwords/signing out on shared devices. | |
| Security tips only | Remove product protection claims and show only user guidance like strong password, app updates, and sign out on shared devices. | ✓ |
| Remove security section | Do not show a security dialog until there are real security settings or features. | |

**User's choice:** Security tips only
**Notes:** Do not claim end-to-end encryption, regular security updates, or other unimplemented protections.

---

## Auth Validation and Error Copy

| Option | Description | Selected |
|--------|-------------|----------|
| Plain actionable | Short English messages like "Enter your email address" and "Check your connection and try again." | ✓ |
| Friendly conversational | Softer messages like "We couldn't find an account with that email." | |
| Technical but clear | Include more Firebase-like detail, while still English. | |

**User's choice:** Plain actionable
**Notes:** Keep login/register messages short, direct, and useful.

---

## the agent's Discretion

- The planner may choose exact English wording as long as it stays concise and factual.
- The planner may choose lightweight static or widget tests for touched copy surfaces.

## Deferred Ideas

- New security/account/privacy features are outside Phase 3.
- Profile image and visual polish remain Phase 4.
- Group consensus remains Phase 5.
