import 'package:flutter/cupertino.dart';
import '../../core/theme/app_colors.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.floatingBar,
        middle: const Text('Privacy Policy'),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Privacy Policy',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.label,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 20),
              _section('1. Information Collection',
                  'We collect information that you provide directly to us when you use the Library Student App, such as when you create a profile, scan a QR code to join a library, or contact support. This information may include your name, student ID, phone number, and library attendance data.'),
              _section('2. Use of Information',
                  'The information we collect is used to provide, maintain, and improve our services, communicate with you, process your library seat bookings and attendance, and personalize your experience within the app.'),
              _section('3. Data Sharing and Security',
                  'Your data is shared securely with the Library Manager and Owner app to facilitate your library access. We implement robust security measures, including data encryption and secure authentication via Firebase, to protect your personal information against unauthorized access.'),
              _section('4. Third-Party Services',
                  'Our app may use third-party services such as Google AdMob to display advertisements. These services may collect information used to identify you in accordance with their respective privacy policies.'),
              _section('5. Changes to This Policy',
                  'We may update our Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page. You are advised to review this Privacy Policy periodically for any changes.'),
              const SizedBox(height: 24),
              Text(
                'Last updated: ${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  color: AppColors.tertiaryLabel,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.systemBlue,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.secondaryLabel,
              fontSize: 14,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
