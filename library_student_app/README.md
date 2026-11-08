<div align="center">

  <img src="https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Objects/Graduation%20Cap.png" alt="Student Portal" width="80" />

  # 🎓 LM Students Portal
  ### Self-Service Mobile Application for Library Students

  <p align="center">
    <a href="https://flutter.dev/"><img src="https://img.shields.io/badge/Flutter-3.11.4+-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" /></a>
    <a href="https://firebase.google.com/"><img src="https://img.shields.io/badge/Firebase-Auth_%26_Firestore-FFCA28?style=for-the-badge&logo=firebase&logoColor=black" alt="Firebase" /></a>
    <a href="#"><img src="https://img.shields.io/badge/PII-Isolated_%26_Encrypted-brightgreen?style=for-the-badge&logo=shield&logoColor=white" alt="Privacy" /></a>
  </p>

</div>

---

## <img src="https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Objects/Mobile%20Phone.png" width="28" /> Overview

The **LM Students Portal** provides students with direct, real-time access to their library membership, shift seats, digital notices, and personal attendance history.

### Core Capabilities
- **Quick Join**: Join any registered library via library code or QR scan.
- **Live Seat Map**: View real-time shift seat allocations and availability.
- **Attendance Insights**: Filterable personal attendance ledger with strict PII boundaries.
- **Digital Notice Board**: Push notices from library management.
- **Leave Applications**: Seamless leave requests with automated seat retention.

## <img src="https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Objects/Locked%20with%20Key.png" width="28" /> Security & Privacy
- **Zero Credentials**: Keystore and configuration keys are never stored in git.
- **Scoped Firestore Queries**: All attendance records and profile data are queried using security rules that prevent cross-student record visibility.
- **Obfuscated Releases**: Release builds utilize R8 code shrinking and Dart symbol obfuscation.

## <img src="https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Objects/Laptop.png" width="28" /> Setup & Running

```bash
# 1. Copy config template
cp android/key.properties.example android/key.properties

# 2. Place google-services.json from Firebase Console into android/app/

# 3. Install & run
flutter pub get
flutter run
```

---
<div align="center">
  <sub>Part of the <b>Library Manager Ecosystem</b> • Maintained by <b>SHARP OP</b></sub>
</div>

