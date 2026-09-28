# Flutter Code Refactor

Use this skill when extracting widgets, deleting unused files, or reorganizing code.

## Steps

1. Before deleting any file: search the entire codebase for its import — only delete if zero imports found
2. When extracting widgets (swipe_card, swipe_buttons): read the full source file, extract cleanly, update the import in the original file
3. After refactor: run `flutter analyze` — zero errors required before finishing
4. Trigger hot reload to confirm the app still works after refactor
