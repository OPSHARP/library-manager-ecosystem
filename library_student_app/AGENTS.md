# Students Portal - Build Instructions

## Overview
Student self-service portal Flutter app. Students scan a QR code or enter a unique library code to join a library, then enter their Student ID to access their dashboard.

## Firebase Setup
**You must add a new Android/iOS app in Firebase Console for this student app:**
1. Firebase Console → Project Settings → Add app
2. **Android**: Package `com.librarymanager.student` — add debug SHA-1, download `google-services.json` → `android/app/`
3. **iOS**: Bundle ID `com.librarymanager.student` — download `GoogleService-Info.plist` → `ios/Runner/`
4. Run: `flutter pub get && flutter run`

## App Name
"Students Portal" (configured in AndroidManifest.xml + Info.plist)

## How Students Join
| Method | How |
|--------|-----|
| **QR Scan** | Scan the library's QR code (shown in owner app's branding screen). QR encodes `{"ownerUid":"...","libraryId":"...","libraryCode":"..."}` |
| **Library Code** | On QR screen, tap "Enter Library Code" and type the 6-char code shown in the owner app (e.g. `A7X3K9`) |

After joining, enter your Student ID (as registered in the owner app).

## Unique Library Code (Owner App)
- Every library auto-generates a unique 6-character alphanumeric code on signup
- Displayed in **Library Setup** and **Library Branding** screens
- Stored in Firestore as `libraryCode` on the library document
- Also stored in top-level `library_registry/{code}` collection for fast lookup
- Students can search by this code in the portal app

## QR Code (Owner App)
- Auto-generated when library is created
- Displayed in **Library Branding** screen using `qr_flutter`
- QR data is JSON: `{"ownerUid":"...","libraryId":"...","libraryCode":"..."}`
- Stored in Firestore as `qrData` on the library document

## Student Features
- **Dashboard**: Seat, books, fees, attendance overview + library info (phone, address)
- **Seat Layout**: Visual grid with color-coded seats
- **My Books**: Book issue/return history
- **Fee Details**: Payment history
- **Attendance**: 60-day log with check-in/out times
- **Profile**: Student info, library contact, **Leave Library** button
  - Leave Library clears local session — student can rejoin anytime

## Security
- **Read-only app**: No Firestore write operations exist in this codebase
- Session stored locally only (SharedPreferences)
- No Firebase Auth — students identified by Student ID only

## Password Reset via OTP + FCM
The app supports PIN/Password reset via OTP sent as push notification:

### Flow
1. Student taps **"Forgot Password?"** on the login screen
2. Enters Student ID → OTP document created in `users/{ownerUid}/password_resets/{resetId}`
3. **Cloud Function** (`sendPasswordResetOtp`) triggers on document creation, reads the student's `fcmToken`, and sends an FCM push notification with the OTP
4. Student receives the push notification → taps it → app opens OTP verification screen
5. Student enters the 6-digit OTP → verified → sets new PIN

### Setup Steps
1. **Enable Blaze plan** in Firebase Console (Cloud Functions require it)
2. **Deploy the Cloud Function:**
   ```bash
   cd firebase
   cd functions && npm install && cd ..
   firebase deploy --only functions
   ```
3. **Ensure FCM is enabled** in your Firebase project (it's on by default for Android/iOS)

### Files
| File | Purpose |
|------|---------|
| `lib/core/services/fcm_service.dart` | FCM token registration, push notification handling, local notification display |
| `lib/features/auth/presentation/providers/password_reset_provider.dart` | OTP generation, verification, PIN reset state management |
| `lib/features/auth/presentation/screens/password_reset_screen.dart` | "Forgot Password" screen — enter Student ID to request OTP |
| `lib/features/auth/presentation/screens/otp_verification_screen.dart` | 6-digit OTP input with auto-fill from push notification |
| `lib/features/auth/presentation/screens/reset_password_screen.dart` | Set new PIN after OTP verification |
| `firebase/functions/index.js` | Cloud Function — sends FCM push when OTP document is created |

## Key Files (Owner App Changes)
| File | Purpose |
|------|---------|
| `lib/features/library_setup/data/models/library_model.dart` | Added `libraryCode`, `qrData` fields |
| `lib/features/library_setup/data/repositories/library_repository.dart` | Added code generation + registry methods |
| `lib/features/library_setup/presentation/screens/library_branding_screen.dart` | Displays live QR code + library code |
| `lib/features/library_setup/presentation/screens/library_setup_screen.dart` | Registers code on save |
| `lib/features/auth/presentation/providers/auth_provider.dart` | Generates code/QR on library creation |

## Release Builds & Obfuscation (Security)
- **ALWAYS** build releases with Dart obfuscation + symbol splitting:
  - Windows: `.\build_release.ps1` (AAB + APK)
  - Manual: `flutter build appbundle --release --obfuscate --split-debug-info=build\symbols`
- R8 (Java/Kotlin minify + resource shrink) is enabled in `android/app/build.gradle.kts` with `proguard-rules.pro`.
- Upload `build/symbols` to Play Console for de-obfuscated crash reports.
- **Sensitive data** (student session/PII) is stored via `lib/core/services/secure_storage_service.dart` (Keystore/Keychain), NOT SharedPreferences. Keep it that way.
