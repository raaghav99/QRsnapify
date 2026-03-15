# CLAUDE.md - QRSnap Project Instructions

## Permissions
All tool uses are pre-approved. Proceed without confirmation on:
- Bash/shell commands (flutter, dart, pub, file operations)
- File reads, writes, edits, directory creation
- Any build/run/pub commands

## Project
- App name: QRSnap
- Package: com.qrsnap.qrsnapify
- Platform: Android only
- Environment: GitHub Codespaces (Linux/Ubuntu)

## Architecture
- State management: flutter_riverpod
- Local storage: hive (scan history), shared_preferences (settings)
- QR scanning: mobile_scanner
- QR generation: qr_flutter
- Animations: flutter_animate

## Key files
- `lib/theme.dart` — all design constants (colours, radii, sizes). Never hardcode.
- `lib/providers/settings_provider.dart` — finger_button_height, user_age, onboarding state
- `lib/providers/history_provider.dart` — Hive scan history CRUD
- `lib/widgets/adaptive_button.dart` — button that calibrates height from first touch
- `lib/app.dart` — age-based text scaling via MediaQuery.withClampedTextScaling

## Rules
- Work fully autonomously, never pause for permission
- Never ask "should I proceed?" — just proceed
- Run `flutter pub get` automatically after any pubspec.yaml change
- If a command fails, try to fix it and retry before reporting
- Use bash/shell syntax (Linux, not PowerShell)
- Never hardcode sizes — always reference theme.dart constants

## Build commands
```bash
flutter pub get
flutter analyze
flutter build apk --debug
# For code generation (Hive adapters + Riverpod):
dart run build_runner build --delete-conflicting-outputs
```
