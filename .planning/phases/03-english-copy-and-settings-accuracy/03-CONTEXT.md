# Phase 3: English Copy and Settings Accuracy - Context

**Gathered:** 2026-07-05T12:53:56Z
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase cleans up user-facing copy and factual settings claims in existing auth, profile/settings, and onboarding surfaces. It must translate remaining German user-facing strings to English and replace misleading settings/security text with accurate current-app wording. It must not add account, privacy, security, profile, or UI capabilities beyond copy and truthful-claim fixes.

</domain>

<decisions>
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

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Product and Phase Scope
- `.planning/PROJECT.md` — Product value, constraints, and current phase sequencing.
- `.planning/REQUIREMENTS.md` — REQ-02 and REQ-09 English copy/settings requirements.
- `.planning/ROADMAP.md` — Phase 3 goal, scope, success criteria, and downstream Phase 4/5 boundaries.
- `.planning/STATE.md` — Current focus and phase position.

### Prior Decisions
- `.planning/phases/02-mvp-correctness-stabilization/02-CONTEXT.md` — Prior decision to avoid UI redesign and keep Phase 3 focused on copy/settings accuracy.
- `.planning/phases/02-mvp-correctness-stabilization/02-VERIFICATION.md` — Confirms Phase 2 correctness scope is complete.

### Codebase Maps
- `.planning/codebase/CONVENTIONS.md` — English-only user-facing string rule, Flutter/Riverpod conventions, and analyzer expectations.
- `.planning/codebase/STRUCTURE.md` — Locations for auth, profile/settings, onboarding, and tests.
- `.planning/codebase/TESTING.md` — Flutter test patterns and acceptable lightweight tests.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `SettingsScreen` in `lib/features/profile/ui/settings_screen.dart` contains the settings list, logout dialog, legal/privacy dialog, and security dialog copy that should be rewritten.
- `LoginScreen` in `lib/features/auth/ui/login_screen.dart` contains German form validation and Firebase auth error mappings.
- `RegisterScreen` in `lib/features/auth/ui/register_screen.dart` contains German display-name/email/password validation and registration error mappings.
- `OnboardingScreen` in `lib/features/onboarding/ui/onboarding_screen.dart` is already English and should be checked but likely does not need changes.

### Established Patterns
- User-facing errors are currently mapped locally in screen helper methods such as `_getErrorMessage`.
- Settings uses simple `ListTile` rows and modal `AlertDialog`s. Keep this structure for Phase 3 unless a copy decision directly requires a small label change.
- Tests should live under `test/` and can use Flutter test assertions or a focused static file-content check.

### Integration Points
- `lib/features/profile/ui/settings_screen.dart`
- `lib/features/auth/ui/login_screen.dart`
- `lib/features/auth/ui/register_screen.dart`
- `lib/features/onboarding/ui/onboarding_screen.dart`
- `test/` for copy/static tests

</code_context>

<specifics>
## Specific Ideas

Use concise, work-focused English. Prefer factual product language over legal boilerplate, especially where the app currently has placeholder company details or unimplemented security claims.

</specifics>

<deferred>
## Deferred Ideas

- Do not implement new privacy controls, account deletion, password reset, password change, two-factor authentication, or security settings in this phase.
- Profile image actions, cached image placeholders, and visual/theme polish remain Phase 4.
- Group ranking and Borda consensus remain Phase 5.

</deferred>

---

*Phase: 3-English Copy and Settings Accuracy*
*Context gathered: 2026-07-05T12:53:56Z*
