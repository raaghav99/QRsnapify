# Pending Fixes — QRSnapify

## W1 — Real Progress Reporting (Important)
- **File:** `lib/shared/services/webview_pdf_service.dart` lines 47-59
- **File:** `android/app/src/main/kotlin/com/qrsnap/qrsnap/MainActivity.kt`
- **Problem:** Dart side fakes progress 0→0.80 with a timer. User sees fake loading bar that doesn't reflect actual work.
- **Fix:** Set up an `EventChannel` on the Kotlin side. Send real progress events at each phase:
  1. `0.10` — WebView page loaded
  2. `0.30` — Scrolling to trigger lazy images
  3. `0.50` — Scroll complete, capturing bitmap
  4. `0.70` — Bitmap captured, generating PDF
  5. `0.90` — PDF written to disk
- Dart side: listen to EventChannel stream, update `PdfFetchLoader` with real values and stage names.
- Remove the fake `Timer.periodic` in `_startFakeProgress()`.

## P5 — IndexedStack Keeps Camera Alive (Important — Can Crash)
- **File:** `lib/features/home_screen.dart` line 19
- **Problem:** `IndexedStack` keeps ALL tabs alive simultaneously. The camera stays active even when user is on Generate or History tab. On low-RAM devices this wastes memory and can cause crashes.
- **Fix:** Replace `IndexedStack` with `PageView` + `AutomaticKeepAliveClientMixin`, or manually dispose/rebuild camera when switching away from Scan tab. Key requirement: camera must stop when not visible, restart when user returns to Scan tab.
- **Why it matters:** Camera + WebView PDF generation running together = high memory pressure = OOM crash on budget phones.

## Lower Priority (Not Urgent)
- **W2** — Fragile height polling: also check `document.readyState === 'complete'` + `window.onload`
- **W4** — Static mutable dialog state in `pdf_fetch_loader.dart`: replace with OverlayEntry or Riverpod provider
- **P2** — History as JSON StringList: migrate to sqflite/drift for 500+ items performance
