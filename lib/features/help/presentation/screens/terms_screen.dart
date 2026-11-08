import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: context.scaffoldBg,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop()),
                    const SizedBox(width: 8),
                    Text('Terms & Privacy', style: AppTypography.headlineSmall),
                  ],
                ),
              ),
              Expanded(
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: context.cardBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TabBar(
                          indicator: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.all(Radius.circular(12))),
                          indicatorSize: TabBarIndicatorSize.tab,
                          labelColor: Colors.white,
                          unselectedLabelColor: context.textTertiaryColor,
                          dividerHeight: 0,
                          tabs: [
                            const Tab(text: 'Terms of Service'),
                            const Tab(text: 'Privacy Policy'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Expanded(
                        child: TabBarView(
                          children: [
                            _TermsContent(),
                            _PrivacyContent(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TermsContent extends StatelessWidget {
  const _TermsContent();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Flexible(child: Text('Last updated: May 28, 2026', style: AppTypography.labelSmall.copyWith(color: AppColors.primary), overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const _Section(
            '1. Acceptance of Terms',
            'By downloading, installing, accessing, or using Library Manager and Owner ("App"), you agree to be bound by these Terms of Service ("Terms"). If you do not agree, do not use the App. These Terms are between Library Manager and Owner ("we", "us") and you ("User", "you").',
          ),

          const _Section(
            '2. Description of Service',
            'Library Manager and Owner is a paid library management application for Android. It provides tools to manage students, seats, attendance, fees, staff, books, and analytics. The app supports 15 languages and 20 currencies, biometric authentication, PDF and Excel export, fee receipt generation, activity logging, and expiring membership alerts. Your data is stored securely in Google Cloud Firestore and synced across your signed-in devices. A local cache is also maintained for offline access.',
          ),

          const _Section(
            '3. Free Tier, Pro Subscription & Payments',
            'Library Manager and Owner offers a free tier with core features and optional paid Pro subscription(s) purchased on the Google Play Store ("Pro"). By purchasing, you agree that:\n\n'
            '(a) Pro subscriptions are managed and billed by Google Play (Play Billing) and renew automatically until cancelled. You can manage or cancel them anytime in your Google Play account settings.\n'
            '(b) The free tier may display ads (see the Privacy Policy). Subscribing to Pro removes ads and unlocks unlimited features.\n'
            '(c) Refunds are handled in accordance with the Google Play refund policy and applicable law.\n'
            '(d) You are purchasing a license to use the App as downloaded — you do not own the App itself.',
          ),

          const _Section(
            '4. User Accounts & Authentication',
            'The App supports multiple authentication methods:\n\n'
            '• Google Sign-In — Used to identify you as the library owner. Your Google profile name and email are used for identification.\n'
            '• Email/Password — You can create an account with an email and password. Passwords are hashed locally and stored securely in your Firestore account for credential recovery.\n'
            '• Firebase Anonymous Auth — Used internally to establish a secure cloud session for Firestore access.\n\n'
            'No personal data from your Google account is collected, stored, or transmitted to any third-party server.',
          ),

          const _Section(
            '5. User Responsibilities',
            'You agree to:\n\n'
            '(a) Provide accurate information during setup and usage.\n'
            '(b) Obtain all necessary consents from students, parents, or guardians before entering their data into the App.\n'
            '(c) Use the App in compliance with all applicable local, state, national, and international laws.\n'
            '(d) Maintain the confidentiality of your device — you are responsible for all activity on the App.\n'
            '(e) Not reverse engineer, decompile, or create derivative works of the App.',
          ),

          const _Section(
            '6. Data Ownership & Privacy',
            'You retain full ownership of all data you enter into the App. Your data is stored in your personal Google Cloud Firestore account, linked to your Google Sign-In identity. We do not access, collect, or sell your data. We are not responsible for data loss resulting from account issues or Google Cloud service interruptions. Regular backups are recommended.',
          ),

          const _Section(
            '7. Intellectual Property',
            'The App, including its code, design, trademarks, and branding, is the exclusive property of the Developer. You may not copy, modify, distribute, sell, or lease any part without written permission.',
          ),

          const _Section(
            '8. Limitation of Liability',
            'TO THE MAXIMUM EXTENT PERMITTED BY LAW, THE DEVELOPER SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, INCLUDING LOSS OF DATA, LOSS OF PROFITS, OR BUSINESS INTERRUPTION. YOU ARE RESPONSIBLE FOR MAINTAINING YOUR OWN BACKUPS.',
          ),

          const _Section(
            '9. Disclaimer of Warranties',
            'THE APP IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND. THE DEVELOPER DISCLAIMS ALL WARRANTIES, EXPRESS OR IMPLIED, INCLUDING MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT. WE DO NOT GUARANTEE THAT THE APP WILL BE ERROR-FREE OR UNINTERRUPTED.',
          ),

          const _Section(
            '10. Third-Party Services',
            'The App uses the following third-party services:\n\n'
            '(a) Google Sign-In (Google LLC) — for authentication.\n'
            '(b) Google Cloud Firestore (Google LLC) — cloud database for storing your library data.\n'
            '(c) SharedPreferences (Android Open Source Project) — local settings storage.\n'
            '(d) Google Fonts — for typography.\n'
            '(e) Mobile Scanner — for QR code and barcode scanning.\n'
            '(f) Local Auth — for biometric authentication (fingerprint/face).\n\n'
            'Google\'s privacy policy applies: https://policies.google.com/privacy',
          ),

          const _Section(
            '11. Termination',
            'We reserve the right to terminate or suspend your access to the App at any time, without prior notice, for conduct that we believe violates these Terms or is harmful to other users, us, or third parties. Upon termination, your right to use the App will immediately cease.',
          ),

          const _Section(
            '12. Changes to Terms',
            'We may update these Terms at any time. Material changes will be communicated through app updates on Google Play. Continued use after changes constitutes acceptance. If you disagree with any change, you must stop using the App.',
          ),

          const _Section(
            '13. Governing Law',
            'These Terms are governed by the laws of India. Any disputes arising from these Terms shall be subject to the exclusive jurisdiction of the courts in India.',
          ),

          const _Section(
            '14. Contact Us',
            'For questions, concerns, or legal requests:\n\n'
            'Email: drillmovies@gmail.com\n\n'
            'We will respond within 15 business days.',
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _PrivacyContent extends StatelessWidget {
  const _PrivacyContent();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_rounded, size: 16, color: AppColors.accent),
                const SizedBox(width: 8),
                Text('Last updated: August 2, 2026', style: AppTypography.labelSmall.copyWith(color: AppColors.accent)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const _Section(
            '1. Overview',
            'This Privacy Policy explains how Library Manager and Owner ("we", "our") handles your information when you use our Android application ("App"). We take your privacy seriously. Your library data is stored in your personal Google Cloud Firestore account and is accessible only to you via Google Sign-In.',
          ),

          const _Section(
            '2. Information We Collect',
            'The App is designed to be privacy-first. Here is exactly what we collect:\n\n'
            'A. INFORMATION YOU PROVIDE:\n'
            '• Student names, phone numbers, parent contacts, addresses, and photos.\n'
            '• Attendance records, fee payment data, and receipt information.\n'
            '• Staff member names, roles, and contact information.\n'
            '• Library setup details (name, seat layouts, working hours).\n'
            '• Book titles, authors, ISBNs, and issue/return records.\n'
            '• Activity logs (student additions, fee collections, attendance marks, seat changes).\n'
            '• Notification preferences and settings.\n\n'
            'This data is stored in your personal Google Cloud Firestore account and is accessible only to you.\n\n'
            'B. ACCOUNT & AUTHENTICATION:\n'
            'You can sign in with Google Sign-In or an email/password account (Firebase Authentication). Your display name and email address are used for identification and account recovery (e.g. password reset emails). Account data is stored in Firebase Authentication and your personal Google Cloud Firestore account.',
          ),

          const _Section(
            '3. Information We DO NOT Collect',
            'We DO NOT collect, transmit, or have access to:\n\n'
            '• Your device location.\n'
            '• Your device identifiers (IMEI, serial number, MAC address).\n'
            '• Your browsing history or other apps.\n'
            '• Your contacts, call logs, or SMS.\n'
            '• Usage analytics, crash logs, or error reports.\n'
            '• Biometric data (fingerprint, face data).',
          ),

          const _Section(
            '4. Permissions We Request',
            'The App may request these Android permissions:\n\n'
            '• CAMERA — To scan QR codes for attendance marking and ISBN barcodes for books. Images are processed on-device; student photos are stored only in your Firestore account.\n'
            '• INTERNET — Required for Google Sign-In, authentication, Firestore cloud sync, and serving ads.',
          ),

          const _Section(
            '5. Third-Party Services & Advertising',
            'The App integrates with the following third-party services:\n\n'
            '• Google Sign-In & Firebase Authentication — Used for authentication (Google and email/password accounts). Google\'s privacy policy applies: https://policies.google.com/privacy\n'
            '• Google Cloud Firestore — Cloud database for storing your library data securely.\n'
            '• Google AdMob — The free tier serves ads (interstitial). AdMob may use the Android advertising identifier and other device signals to deliver personalized or non-personalized ads, and applies Google\'s ad privacy policy: https://policies.google.com/privacy\n'
            '• Firebase Remote Config — Loads app configuration (such as ad unit IDs) over the network.\n'
            '• Google Fonts — Used for app typography.\n'
            '• Mobile Scanner — QR code and barcode scanning for attendance and books.\n'
            '• Local Auth — Biometric authentication (fingerprint/face) for app security.\n'
            '• SharedPreferences — Android local key-value storage for app settings.\n\n'
            'Your library data in Firestore is accessible only to your authenticated account.\n\n'
            'ADVERTISING: The free tier displays ads served by Google AdMob. Subscribing to Pro removes all ads. You can opt out of personalized advertising via your device\'s ad settings (Settings > Ads on Android); ads will then be non-personalized.',
          ),

          const _Section(
            '6. Data Storage & Security',
            'Your data is stored using:\n\n'
            '• Google Cloud Firestore — for all library data (students, fees, attendance, books, etc.).\n'
            '• SharedPreferences — for app settings (theme, currency, language).\n\n'
            'Security measures:\n'
            '• Data is encrypted in transit (TLS) and at rest (Google-managed encryption).\n'
            '• Access is restricted to your authenticated Google account.\n'
            '• Firestore security rules enforce per-user data isolation.\n\n'
            'YOU are responsible for device security. Enable a screen lock (PIN, pattern, or biometric) to protect the App.',
          ),

          const _Section(
            '7. Data Sharing & Disclosure',
            'We do NOT share, sell, rent, or trade your personal information with any third party. We cannot access your Firestore data — it is tied to your personal Google account.\n\n'
            'LEGAL DISCLOSURE: We will only disclose information if required by law (e.g., a valid court order from a competent Indian authority). In such cases, we will notify you first unless prohibited by law.',
          ),

          const _Section(
            '8. Data Retention & Deletion',
            'RETENTION: Your data is retained in your Firestore account for as long as your account exists.\n\n'
            'DELETION: You can delete all data at any time via:\n'
            '• Settings > Delete Account within the App (removes all Firestore data).\n'
            '• Deleting your Google account (data is automatically purged by Google).\n\n'
            'Deletion is permanent and cannot be undone.',
          ),

          const _Section(
            '9. Children\'s Privacy (COPPA)',
            'The App is not directed at children under 13. We do not knowingly collect personal information from children. If you are a parent or guardian and believe your child has provided data through the App, contact us immediately at drillmovies@gmail.com and we will advise you on how to delete it from your device.\n\n'
            'The App is designed for use by library owners and administrators who are responsible adults. Any student data entered is done so by the adult library owner with appropriate consent.',
          ),

          const _Section(
            '10. Your Rights (GDPR & CCPA)',
            'Since your data is stored securely in your personal Google Cloud Firestore account, you have direct and complete control:\n\n'
            'GDPR RIGHTS (European Economic Area users):\n'
            '• Right to Access — You can view all data within the App.\n'
            '• Right to Rectification — Edit any data directly in the App.\n'
            '• Right to Erasure — Delete data via Settings > Clear All Data.\n'
            '• Right to Data Portability — Export your data via backup (.json file).\n\n'
            'CCPA RIGHTS (California residents):\n'
            '• Right to Know — What data exists is visible in the App.\n'
            '• Right to Delete — Clear data from App settings.\n'
            '• Right to Opt-Out — No data is sold, so no opt-out is needed.\n\n'
            'To exercise any right, contact drillmovies@gmail.com.',
          ),

          const _Section(
            '11. Data Breach Notification',
            'Your data is stored in Google Cloud Firestore, which is managed by Google and subject to their security practices. In the unlikely event of a security vulnerability in the App itself, we will:\n\n'
            '1. Release a patched version on Google Play immediately.\n'
            '2. Notify users via the app update description on Google Play.\n'
            '3. Provide instructions to secure your data.',
          ),

          const _Section(
            '12. Changes to This Policy',
            'We may update this policy as needed. Material changes will be communicated through:\n'
            '• App update descriptions on Google Play.\n'
            '• An in-app notification on the next launch after update.\n\n'
            'The "Last updated" date at the top will reflect the most recent revision.',
          ),

          const _Section(
            '13. Contact Us',
            'For privacy questions, data requests, or concerns:\n\n'
            'Email: drillmovies@gmail.com\n\n'
            'We will acknowledge your request within 5 business days and respond fully within 15 business days.',
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String content;
  const _Section(this.title, this.content);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.titleSmall.copyWith(color: AppColors.primary)),
          const SizedBox(height: 8),
          Text(content, style: AppTypography.bodyMedium.copyWith(color: context.textSecondaryColor, height: 1.6)),
        ],
      ),
    );
  }
}
