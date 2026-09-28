# Flutter Feature Builder

Use this skill when building new features or completing partial/empty files.

## Steps

1. Read AGENTS.md to understand the architecture
2. Read the relevant existing files to understand patterns already used
3. Follow Feature-First Clean Architecture: create UI file, then Logic (Controller), then Data (Repository)
4. Use Riverpod providers — match the pattern used in existing controllers
5. Add the new package to pubspec.yaml if needed, then run `flutter pub get`
6. Run `flutter analyze` after writing every file
7. Trigger hot reload via Dart MCP
8. Use Marionette MCP to interact with the running app and confirm the feature works
