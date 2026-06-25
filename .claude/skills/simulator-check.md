---
description: Visually verify the running SwipeTrip simulator after code changes
---

Use the Flutter MCP server to check the running app. Steps:

1. **Hot reload** — trigger a hot reload so the simulator reflects the latest saved code.

2. **Check for runtime errors** — read the Flutter log output. Flag any:
   - Red screen / error widget
   - Null pointer exceptions
   - Provider errors (`ProviderException`, `StateError`)
   - Firestore permission denied errors

3. **Navigate to changed screens** — based on `git diff --name-only HEAD | grep 'lib/'`, identify which feature screens changed and navigate there in the simulator.

4. **Capture and report** — take a screenshot (if MCP supports it) and report:
   - Does the screen render without errors?
   - Are all strings in English (no German text visible)?
   - Does the UI match the expected layout for that screen?

5. **Verdict**:
   - **PASS** — no runtime errors, screen renders correctly
   - **FAIL** — describe exactly what broke and which file likely caused it

If the simulator is not running, say so and recommend: `flutter run` in a terminal before invoking this skill.
