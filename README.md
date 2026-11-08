<div align="center">

  <img src="https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Objects/Books.png" alt="Library System" width="90" />

  # 📚 Library Manager Ecosystem
  ### Next-Gen Dual-App SaaS Template for Library Owners & Students

  <p align="center">
    <b>A high-performance, white-label friendly library management template engineered with Flutter & Firebase.</b>
  </p>

  <!-- Badges -->
  <p align="center">
    <a href="https://flutter.dev/"><img src="https://img.shields.io/badge/Flutter-3.11.4+-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" /></a>
    <a href="https://dart.dev/"><img src="https://img.shields.io/badge/Dart-3.0+-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart" /></a>
    <a href="https://firebase.google.com/"><img src="https://img.shields.io/badge/Firebase-Serverless-FFCA28?style=for-the-badge&logo=firebase&logoColor=black" alt="Firebase" /></a>
    <a href="https://www.typescriptlang.org/"><img src="https://img.shields.io/badge/TypeScript-Cloud_Functions-3178C6?style=for-the-badge&logo=typescript&logoColor=white" alt="TypeScript" /></a>
    <a href="LICENSE"><img src="https://img.shields.io/badge/License-White--Label_BYOB-4CAF50?style=for-the-badge&logo=open-source-initiative&logoColor=white" alt="License" /></a>
  </p>

  <p align="center">
    <a href="#-architecture-overview">Architecture</a> •
    <a href="#-reskin--white-label-guide">Reskin Guide</a> •
    <a href="#-dual-app-ecosystem">Apps</a> •
    <a href="#-security--zero-secrets-policy">Security</a> •
    <a href="#-getting-started">Setup</a> •
    <a href="#-license--usage-terms">License</a>
  </p>

</div>

---

## <img src="https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Objects/Laptop.png" width="32" /> Architecture Overview

This repository is structured as a unified monorepo housing both client applications and the backend infrastructure:

```
📦 Library Manager Ecosystem
 ├── 📱 android/ & lib/               # Owner App (com.librarymanager.owner)
 ├── 🎓 library_student_app/          # Student Portal App (com.librarymanager.student)
 ├── ⚡ firebase/
 │    ├── 📜 firestore.rules          # Granular multi-tenant RBAC rules
 │    ├── 📜 storage.rules            # Secure bucket asset rules
 │    └── 💻 functions/src/           # Cloud Functions (TypeScript)
 │         ├── subscription_validation.ts  # Atomic Play Store receipt verification
 │         ├── attendance_alerts.ts        # Automated student check-in alerts
 │         ├── fee_reminders.ts            # Scheduled overdue notifications
 │         ├── student_library.ts          # Shift seats & membership workflows
 │         └── rate_limit.ts               # Brute-force & DDoS protection
 └── 📄 tos.md & privacy.md           # Legal & Google Play Trader Compliance
```

```mermaid
graph TD
    subgraph Clients
        OA[📱 Library Manager & Owner App]
        SA[🎓 LM Students Portal App]
    end

    subgraph Firebase Cloud Infrastructure (Your Own Backend)
        AUTH[🔐 Firebase Authentication<br/>Biometrics / OAuth / Passwords]
        FS[(🗄️ Cloud Firestore<br/>Subcollections + Atomic Transactions)]
        CF[⚡ TypeScript Cloud Functions<br/>Subscription / Rate Limits / Seat Sync]
        ST[📦 Cloud Storage<br/>Digital Fee Receipts / QR Badges]
    end

    OA -->|Owner Admin CRUD| AUTH
    OA -->|Realtime Synced State| FS
    OA -->|Cloud Reports & In-App Purchases| CF
    OA -->|Store Invoices| ST

    SA -->|Self-Service Join / Scan| AUTH
    SA -->|Scoped Read & Live Shifts| FS
    SA -->|Leave Requests / Shift Claims| CF
```

---

## <img src="https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Objects/Artist%20Palette.png" width="32" /> Reskin & White-Label Guide

You are free to download, re-brand, and deploy this template for your own library business! Follow these 4 steps to safely make it your own:

### 1. Change Package Name & App Identity
Update package IDs in `android/app/build.gradle.kts` and `AndroidManifest.xml` (e.g. from `com.librarymanager.owner` to `com.yourbrand.library`):
```bash
# Recommended tool for quick rename:
flutter pub global activate rename
rename setBundleId --targets android,ios --value "com.yourbrand.library"
rename setAppName --targets android,ios --value "Your Library Name"
```

### 2. Connect Your Own Firebase (Bring Your Own Backend)
You **MUST** connect the apps to your own Firebase project (do NOT use author's backend):
```bash
# Install FlutterFire CLI if you haven't:
dart pub global activate flutterfire_cli

# Configure Owner App:
flutterfire configure

# Configure Student App:
cd library_student_app
flutterfire configure
```
This automatically generates your own `lib/firebase_options.dart` and downloads `google-services.json`.

### 3. Replace Icons & Branding
- Replace icons in `android/app/src/main/res/` and `assets/` with your own library logo.
- Customize color palette in `lib/core/theme/` to match your brand.

### 4. Setup Release Signing Keystore
Copy `key.properties.example` to `key.properties` and add your own keystore file:
```bash
cp android/key.properties.example android/key.properties
```

---

## <img src="https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Objects/Mobile%20Phone.png" width="32" /> Dual-App Ecosystem

### 1. 🏢 Library Manager and Owner (Admin App)
- **Shift-Wise Seat Management**: Visual seat grid supporting multi-shift occupancy (Morning, Afternoon, Evening, Night, Full-Day).
- **Automated Digital Fee Receipts**: Generates branded fee receipts, handles partial payments, discounts, and overdue tracking.
- **Biometric Security Vault**: Local authentication gate with cryptographic PIN/Biometric lock and automatic inactivity cooldown.
- **Offline Attendance Sync**: Zero-downtime offline attendance queue with poison-pill retry guards.
- **Operational Expense Tracker**: Category-wise expense logging with monthly financial analytics.
- **Dynamic Notice Board**: Push notices and operational guidelines straight to all registered students.
- **Auto Cloud Backup**: Multi-chunk Firestore document backups to bypass the 1MB document limit.

### 2. 🎓 LM Students Portal (Student Self-Service)
- **One-Tap QR / Code Joining**: Enter library token to bind student profile instantly.
- **Real-Time Seat Availability**: Live visualization of vacant seats and shifts.
- **Attendance History & Analytics**: Personal attendance logs with strict PII isolation.
- **Instant Digital Notices**: Real-time notifications for library timings, fees, holidays, and rules.
- **Leave Request Management**: Submit and track leave requests with automated seat retention.

---

## <img src="https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Objects/Shield.png" width="32" /> Security & Zero-Secrets Policy

This repository contains **ZERO active backend credentials, API keys, or private keystores**:

| Security Vector | Implementation Detail |
|---|---|
| 🔑 **Zero-Secret Codebase** | All keystore passwords, signing files (`*.jks`, `key.properties`), and private Firebase configuration are 100% excluded via `.gitignore`. Sample templates provided. |
| 🛡️ **Bring Your Own Backend** | Developers must connect their own Firebase project via `flutterfire configure`. |
| ⚡ **Atomic In-App Purchases** | Google Play subscription validation runs inside Firestore transactions preventing duplicate token reuse attacks. |
| 🔒 **Granular Firestore Rules** | Multi-tier security rules ensuring students can NEVER read other students' data or modify seat allocations without server validation. |
| 🧬 **Code Minification & Obfuscation** | Release builds enforce R8 shrinking and Dart-level AOT symbol obfuscation with split debug info. |

---

## <img src="https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Travel%20and%20places/Rocket.png" width="32" /> Quick Start

```bash
# Clone the template
git clone https://github.com/OPSHARP/library-manager-ecosystem.git
cd library-manager-ecosystem

# Setup your own Firebase
flutterfire configure

# Run Owner App
flutter pub get
flutter run
```

---

## <img src="https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Objects/Hammer%20and%20Wrench.png" width="32" /> Production Builds

```powershell
# Build Owner App (AAB + APK with Dart obfuscation)
.\build_release.ps1

# Build Student App (AAB + APK with Dart obfuscation)
cd library_student_app
.\build_release.ps1
```

---

## <img src="https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Objects/Scroll.png" width="32" /> License & Usage Terms

This project is licensed under the **SHARP OP Commercial Template & White-Label License (BYOB)**.

- **You ARE permitted to**: Clone, fork, modify, reskin, and distribute your own branded mobile applications commercially.
- **You MUST NOT**: Use the author's private Firebase backend, consume author's cloud quotas, or use the trademarked name/branding of "SHARP OP".

See the full [LICENSE](LICENSE) file for complete legal terms.

---

<div align="center">
  <sub>Created by <b>SHARP OP</b> • Enterprise Software Systems</sub>
</div>
