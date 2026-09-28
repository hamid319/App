# Flutter Bug Fixer

Use this skill when fixing bugs, errors, crashes, or incomplete logic in existing Dart/Flutter files.

## Steps

1. Read the file fully before changing anything
2. Run `flutter analyze` to get all current errors
3. Fix errors one file at a time
4. After each fix run `flutter analyze` again
5. Trigger hot reload via Dart MCP
6. Use Marionette MCP to take a screenshot and verify the fix visually
7. Do not introduce new dependencies unless the bug cannot be fixed without one
8. If the fix requires touching a Firestore transaction, be extremely careful — read the full transaction block first
