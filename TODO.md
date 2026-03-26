# QRSnapify TODO

## App Icon
- [ ] Design app icon (QR code themed, clean, recognizable at small sizes)
- [ ] Generate all required sizes (mdpi through xxxhdpi)
- [ ] Replace default Flutter icon in `android/app/src/main/res/mipmap-*`
- [ ] Update `android:icon` in AndroidManifest.xml if needed
- [ ] Adaptive icon (foreground + background layers) for Android 8+

## Website / Landing Page
- [ ] Design single-page landing site for QRSnap
- [ ] Hero section — app name, tagline, screenshot mockup
- [ ] Features section — scan, generate, PDF export, print
- [ ] Download / Play Store badge link
- [ ] Privacy policy page (required for Play Store)
- [ ] Host (GitHub Pages / Vercel / Netlify)

## Code Fixes (from CODE_AUDIT.md)
- [ ] Fix 4 vulnerabilities (V1-V4)
- [ ] Delete 6 dead code items (D1-D6)
- [ ] Fix 6 bugs (B1-B6)
- [ ] Clean up 4 workarounds (W1-W4)
- [ ] Optimize 5 performance issues (P1-P5)

## Play Store Prep
- [ ] App icon (see above)
- [ ] Feature graphic (1024x500)
- [ ] Screenshots (phone, at least 4)
- [ ] Short description (80 chars)
- [ ] Full description
- [ ] Privacy policy URL
- [ ] Build signed AAB (`flutter build appbundle --release`)
- [ ] Content rating questionnaire
- [ ] Target API level compliance
