# Play Store Release — Library Manager and Owner

## Version
- **Version Name:** 3.1.0
- **Version Code:** 4
- **Build Date:** 2026-08-08

## App Identity
- **Package (applicationId):** `com.librarymanager.owner`
- **Firebase App ID (Android):** `1:412683622526:android:4fd1723331fae6d662e02f`
- **minSdk:** 24 (Android 7.0)
- **targetSdk / compileSdk:** 36 (Android 16)
- **Signing:** release keystore from `key.properties`

## Security — SafetyNet → Play Integrity
- App already uses **Play Integrity** via `firebase_app_check`:
  `lib/main.dart:44` → `AndroidProvider.playIntegrity` (release), Debug provider in debug builds.
- No SafetyNet references exist anywhere in app code or Gradle config.
- Added explicit exclusion of the deprecated bundled artifact
  `com.google.firebase:firebase-appcheck-safetynet` in `android/app/build.gradle.kts`
  so it can never be referenced or shipped.

## Play Console Requirements Checklist
- [ ] Upload `build/app/outputs/bundle/release/app-release.aab`
- [ ] Upload `build/symbols` for crash de-obfuscation
- [ ] Advertising ID declaration: **Yes — uses advertising ID** (AdMob interstitial)
- [ ] AD_ID permission: present in merged manifest (verified)
- [ ] Play Integrity API App Check: enabled (release uses Play Integrity)

## Release Notes (short)
- Faster student deletion
- Currency syncs to Students Portal
- Join/leave notifications auto-delete after action
- Updated in-app updates
- Performance & stability fixes

## Artifacts
- AAB: `build/app/outputs/bundle/release/app-release.aab`
- APK: `build/app/outputs/flutter-apk/app-release.apk`
