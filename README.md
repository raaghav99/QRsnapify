# QRSnapify

A fast, beautiful QR code scanner and generator for Android. No ads. No tracking. Forever free.

> This is a private repository. Do not share or redistribute the source code.

## Features

- **Instant Scan** — Point your camera and scan any QR code instantly
- **Generate QR Codes** — Create QR codes for URLs, text, email, phone, Wi-Fi, UPI, SMS, WhatsApp, vCard contacts, and geo locations
- **Save as PDF** — Export any webpage to a full-page PDF with complete content rendering
- **Print QR Codes** — Print generated QR codes on A4 paper with a clean, centered layout
- **Favourites & History** — Every scan is saved. Star the important ones. Filter and search anytime
- **Themeable** — Pick your accent color or set different colors for each day of the week
- **UPI Safety Warnings** — Bilingual (English + Hindi) payment warnings with scam detection
- **URL Security Check** — 11-point local security analysis for scanned URLs including typosquatting, homograph attacks, and entropy analysis

## Tech Stack

- **Framework:** Flutter (Dart)
- **State Management:** Riverpod
- **Platform:** Android
- **PDF Engine:** Native Android WebView + PdfDocument API (Kotlin)
- **Scanner:** mobile_scanner (ML Kit)

## QR Types Supported

| Type | Scan | Generate |
|------|------|----------|
| URL | Yes | Yes |
| Text | Yes | Yes |
| Email | Yes | Yes |
| Phone | Yes | Yes |
| Wi-Fi | Yes | Yes |
| UPI | Yes | Yes |
| SMS | — | Yes |
| WhatsApp | — | Yes |
| vCard | — | Yes |
| Location | — | Yes |

## Building

```bash
# Clone
git clone https://github.com/raaghav99/QRsnapify.git
cd QRsnapify

# Install dependencies
flutter pub get

# Run on connected device
flutter run
```

**Requirements:**
- Flutter 3.41+
- JDK 17
- Android SDK with API 21+ target

## Project Structure

```
lib/
├── app/              # Theme, providers, routes
├── features/
│   ├── generate/     # QR code generation (10 types)
│   ├── history/      # Scan history with favourites
│   ├── scan/         # Camera-based QR scanning
│   ├── settings/     # Theme customization
│   └── home_screen.dart
├── models/           # ScanResult, QRType
└── shared/
    ├── services/     # History, calibration, PDF
    └── widgets/      # Result sheet, buttons, loaders
```

## License

Proprietary. All rights reserved.
