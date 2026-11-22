# Kickvolt

Flutter app. Architecture and state management rules are imported from the
Wavezio mobile app and adapted (no verticals; features live directly under
`lib/features/`).

- Folder structure, naming, layers, barrels, DI, routing:
  @.ai/rules/structure.md
- State management (Bloc/Cubit + Freezed, error handling, testing):
  @.ai/rules/state_management.md

Before calling a task done: run code generation if Freezed/json/route/API
files changed, then `flutter analyze` and `dart format .`.
