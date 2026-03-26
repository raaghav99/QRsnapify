# QRSnapify Code Audit — 2026-03-26

## Priority 1: Vulnerabilities (Fix First)

### V1 — No URL scheme validation in native PDF generator
- **File:** `android/app/src/main/kotlin/com/qrsnap/qrsnap/MainActivity.kt` line 253
- **Issue:** `webView.loadUrl(url)` accepts any URL including `javascript:` or `file:///` schemes
- **Fix:** Add before `webView.loadUrl(url)`:
```kotlin
if (!url.startsWith("http://") && !url.startsWith("https://")) {
    sendError("INVALID_URL", "Only http/https URLs allowed")
    return
}
```

### V2 — launchUrl with any URI scheme
- **File:** `lib/shared/widgets/qr_result_sheet.dart` lines 70-82
- **Issue:** `launchUrl(uri)` called with any scheme from scanned QR. Crafted QR could trigger unexpected intents
- **Fix:** Whitelist schemes before calling launchUrl:
```dart
final allowed = {'http', 'https', 'tel', 'mailto', 'sms', 'upi', 'geo'};
if (!allowed.contains(uri.scheme)) return;
```

### V3 — WebView security settings too permissive
- **File:** `MainActivity.kt` line 61-62
- **Issue:** JS + DOM storage enabled, no file access restrictions
- **Fix:** Add after settings block:
```kotlin
webView.settings.allowFileAccess = false
webView.settings.allowContentAccess = false
```

### V4 — UPI VPA not URI-encoded
- **File:** `lib/features/generate/generate_controller.dart` line 78
- **Issue:** `pa=$upiVpa` — special chars like `&` or `=` break URI
- **Fix:** Change to `pa=${Uri.encodeComponent(upiVpa)}`

---

## Priority 2: Dead Code (Delete These)

### D1 — Unused methods in generate_screen.dart
- **File:** `lib/features/generate/generate_screen.dart` lines ~463-476
- **What:** `_hintText()` and `_keyboardType()` methods — unused after refactor to per-type SimpleField
- **Fix:** Delete both methods

### D2 — Unused _QrActionBtn widget
- **File:** `lib/features/generate/generate_screen.dart` lines ~481-537
- **What:** `_QrActionBtn` class — replaced by AdaptiveButton, never instantiated
- **Fix:** Delete entire class

### D3 — Unused setProcessing in scan_controller
- **File:** `lib/features/scan/scan_controller.dart` line 92
- **What:** `setProcessing()` and `isProcessing` field never called/read
- **Fix:** Remove method + field from ScanState

### D4 — Unused import in wind_painter
- **File:** `lib/shared/painters/wind_painter.dart` line 3
- **What:** `import '../../app/theme.dart'` never used
- **Fix:** Delete import

### D5 — Unused _expandedDay in settings_screen
- **File:** `lib/features/settings/settings_screen.dart` line 15
- **What:** `_expandedDay` written but never read
- **Fix:** Remove field and setState calls

### D6 — Empty duplicate MainActivity.kt
- **File:** `android/app/src/main/kotlin/com/qrsnap/qrsnapify/MainActivity.kt`
- **What:** Entire file under OLD package name — completely empty/unused
- **Fix:** Delete `android/app/src/main/kotlin/com/qrsnap/qrsnapify/` directory

---

## Priority 3: Bugs

### B1 — Side effects in Builder.build()
- **File:** `lib/features/generate/generate_screen.dart` lines 254-259
- **Issue:** `_scrollToActions()` fires on every rebuild, not just first QR appearance
- **Fix:** Move to `ref.listen` or check with a proper lifecycle method

### B2 — TLD check matches URL paths, not just host
- **File:** `lib/shared/widgets/qr_result_sheet.dart` line 136
- **Issue:** `lowerUrl.endsWith('.tk')` matches paths like `/file.tk`, not just domains
- **Fix:** Parse `Uri.parse(url).host` and check TLD on host only

### B3 — "New domain" heuristic checks full URL
- **File:** `lib/shared/widgets/qr_result_sheet.dart` line 142
- **Issue:** `lowerUrl.split('.').length == 2` counts dots in entire URL not just host
- **Fix:** Use `Uri.parse(url).host.split('.')` instead

### B4 — ref.read in dispose() unreliable
- **File:** `lib/features/scan/scan_screen.dart` lines 37-38
- **Issue:** Provider scope may be torn down during dispose
- **Fix:** Use provider's `onDispose` callback instead

### B5 — Theme flash on startup
- **File:** `lib/features/settings/settings_provider.dart` lines 47-49
- **Issue:** `build()` returns defaults before async `_load()` finishes
- **Fix:** Load settings in `main()` before `runApp()` and pass initial values

### B6 — Static counter can produce duplicate IDs
- **File:** `lib/models/scan_result.dart` line 72
- **Issue:** `_counter` resets on hot restart, theoretically duplicate IDs
- **Fix:** Add random component or use UUID

---

## Priority 4: Workarounds to Clean Up

### W1 — Fake progress timer
- **File:** `lib/shared/services/webview_pdf_service.dart` lines 47-59
- **Issue:** No real progress from native side, timer fakes 0→0.80
- **Fix:** Send progress events from Kotlin via MethodChannel EventChannel

### W2 — Fragile height polling
- **File:** `MainActivity.kt` lines 95-115
- **Issue:** `pollUntilStable` recursively polls document height — fragile for SPAs
- **Fix:** Also check `document.readyState === 'complete'` + `window.onload`

### W3 — Silent 25000px truncation
- **File:** `MainActivity.kt` line 163
- **Issue:** Hard cap silently truncates very long pages
- **Fix:** Log warning or notify user when truncation occurs

### W4 — Static mutable dialog state
- **File:** `lib/shared/widgets/pdf_fetch_loader.dart` lines 10-11
- **Issue:** Static `_dialogState` and `_dialogContext` — fragile if multiple dialogs
- **Fix:** Use OverlayEntry or Riverpod provider

---

## Priority 5: Performance

### P1 — Huge bitmap allocation (ARGB_8888)
- **File:** `MainActivity.kt` line 178
- **Issue:** 1080x25000 = ~103MB bitmap. Can OOM on low-RAM devices
- **Fix:** Use `Bitmap.Config.RGB_565` (half memory, no alpha needed for PDF)

### P2 — History stored as JSON StringList
- **File:** `lib/shared/services/history_service.dart`
- **Issue:** Full list deserialized/serialized on every operation (up to 500 items)
- **Fix:** Migrate to sqflite/drift/isar for better performance

### P3 — Animations on every rebuild
- **File:** `lib/features/history/history_screen.dart` lines 443-465
- **Issue:** fadeIn + slideX animations run on every rebuild, not just initial
- **Fix:** Track if list has been shown, skip animation on subsequent rebuilds

### P4 — SharedPreferences not cached
- **File:** `lib/shared/services/calibration_service.dart`
- **Issue:** `SharedPreferences.getInstance()` called every method call
- **Fix:** Cache prefs instance in field on first call

### P5 — IndexedStack keeps all tabs alive
- **File:** `lib/features/home_screen.dart` line 19
- **Issue:** Camera stays active even on Generate/History tabs
- **Fix:** Consider PageView + AutomaticKeepAliveClientMixin for lazy building

---

## Summary

| Category | Count | Priority |
|----------|-------|----------|
| Vulnerabilities | 4 | Fix NOW |
| Dead code | 6 | Quick deletes |
| Bugs | 6 | Fix soon |
| Workarounds | 4 | Clean up when time allows |
| Performance | 5 | Optimize later |
| **Total** | **25** | |

**Next session:** Start with V1-V4 + D1-D6 (10 items, all quick fixes), then B1-B6.
