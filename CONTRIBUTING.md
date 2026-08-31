# Contributing Guide

## Architecture Rules

This project follows **Clean Architecture** principles. All code must adhere to the following structure:

### Layer Separation

1. **Presentation Layer** (`lib/features/*/presentation/`)
   - Contains UI widgets, pages, and BLoCs/Cubits
   - **MUST NOT** directly call data sources or services
   - **MUST** use use cases from the domain layer
   - **MUST** use GoRouter for navigation (not MaterialPageRoute)

2. **Domain Layer** (`lib/features/*/domain/`)
   - Contains entities, use cases, and repository interfaces
   - **MUST** be pure Dart (no Flutter dependencies)
   - **MUST** use `Either<Failure, T>` for error handling (dartz package)

3. **Data Layer** (`lib/features/*/data/`)
   - Contains repository implementations, data sources, and models
   - **MUST** implement domain repository interfaces
   - **MUST** use Dio for network calls (not http package)
   - **MUST** map exceptions to domain failures

### State Management

- Use **BLoC/Cubit** per feature/aggregate (not monolithic blocs)
- Events and States **MUST** be immutable (extend Equatable)
- **MUST NOT** use StatefulWidget for trivial state - prefer BLoC

### Logging

- **MUST** use `AppLogger` (never `print`)
- **MUST** guard debug logs with `if (!kReleaseMode)`
- Use appropriate log levels: `debug`, `info`, `warning`, `error`

### Navigation

- **MUST** use `GoRouter` for all navigation
- **MUST** use named routes from `AppRouter`
- **MUST NOT** use `Navigator.push(MaterialPageRoute(...))`

### Network

- **MUST** use Dio with interceptors (auth, retry, cache)
- **MUST** use HTTPS in production
- **MUST** handle timeouts (10s default)
- **MUST** map network errors to domain failures

### Security

- **MUST** use `flutter_secure_storage` for tokens/credentials
- **MUST NOT** hardcode API keys or secrets
- **MUST** use HTTPS for all production endpoints

## Size Optimization Checklist

Before submitting a PR, ensure:

- [ ] No unused imports or dead code
- [ ] Assets are compressed and optimized
- [ ] No large files in assets (use network loading if >100KB)
- [ ] Release build uses `--obfuscate` and `--split-debug-info`
- [ ] App bundle size is <30MB
- [ ] No `print` statements (use AppLogger)
- [ ] Debug logging is guarded with `kReleaseMode`

## Testing

- **MUST** write unit tests for use cases
- **MUST** write bloc tests for state management
- **MUST** maintain >80% code coverage
- Use `bloc_test` for BLoC testing
- Use `mocktail` for mocking

## Code Style

- Follow `very_good_analysis` lint rules
- Run `flutter analyze` before committing
- Use `dart format` to format code
- Prefer `const` constructors where possible

## Release Checklist

1. Update version in `pubspec.yaml`
2. Run `flutter pub get`
3. Run `flutter analyze`
4. Run `flutter test --coverage`
5. Build release: `./scripts/build_production.sh`
6. Verify size: `flutter build appbundle --analyze-size`
7. Test on physical device
8. Update CHANGELOG.md

## Verification Commands

```bash
# Analyze code
flutter analyze

# Run tests with coverage
flutter test --coverage

# Check dependencies
flutter pub run dependency_validator

# Build and analyze size
flutter build appbundle --release --analyze-size

# Check for unused assets
flutter pub run dependency_validator --no-fatal-warnings
```

## Questions?

If you're unsure about architecture decisions, please:
1. Check existing code for patterns
2. Review this guide
3. Ask in PR comments before implementing

