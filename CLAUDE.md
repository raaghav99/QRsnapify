# CLAUDE.md - QRSnapify Project Instructions

## Permissions
All tool uses are pre-approved. Proceed without confirmation on:
- Bash/shell commands (flutter, dart, pub, file operations)
- File reads, writes, edits, directory creation
- Any build/run/pub commands

## Project
- App name: QRSnap
- Package: com.qrsnap.qrsnap
- Project dir: C:\dev\QRSnapify (moved out of OneDrive to avoid sync conflicts)
- Platform: Android only

## Rules
- Work fully autonomously, never pause for permission
- Never ask "should I proceed?" — just proceed
- Run `flutter pub get` automatically after any pubspec.yaml change
- If a command fails, try to fix it and retry before reporting
- Use PowerShell/CMD syntax for all shell commands (Windows)
- Never work from OneDrive paths — causes file lock conflicts during build