# AGENTS Guide

## Build / Lint / Test Commands
- **Build**: `/opt/flutter/bin/dart compile exe lib/main.dart -o bin/vote` (or `flutter build` if applicable).
- **Lint**: `/opt/flutter/bin/dart analyze` (or `flutter analyze`).
- **Run all tests**: `/opt/flutter/bin/flutter test --dart-define-from-file=devel_dart_define.json` (the dart-defines are required: `ApiConfig` throws without a valid `FLAVOR`).
- **Run a single test**: `/opt/flutter/bin/flutter test --dart-define-from-file=devel_dart_define.json path/to/file_test.dart --plain-name "test name"`.
- **Watch tests**: `/opt/flutter/bin/flutter test --dart-define-from-file=devel_dart_define.json --watch`.

## Code Style Guidelines
- **Imports**: Order alphabetically, separate third‑party, package and relative imports with a blank line.
- **Formatting**: Run `/opt/flutter/bin/dart format .` before commits.
- **Types**: Use explicit types; avoid `dynamic` unless necessary.
- **Naming**:
  - Classes/Enums: `PascalCase`.
  - Variables/Functions: `camelCase`.
  - Constants: `SCREAMING_SNAKE_CASE`.
- **Error handling**: Prefer `try/catch` with specific exception types; rethrow only when adding context.
- **Async**: Use `async/await`; return `Future<T>` instead of `Future<dynamic>`.
- **Documentation**: Add Dartdoc comments (`///`) for public members.
- **Testing**: Keep tests in `test/` mirroring lib structure; name files `*_test.dart`.
- **Commit style**: Short imperative summary, optional detailed body.
