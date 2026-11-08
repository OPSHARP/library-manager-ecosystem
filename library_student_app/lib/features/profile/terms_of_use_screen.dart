import 'package:flutter/cupertino.dart';
import '../../core/theme/app_colors.dart';

class TermsOfUseScreen extends StatelessWidget {
  const TermsOfUseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.floatingBar,
        middle: const Text('Terms of Use'),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Terms of Use',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.label,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 20),
              _section('1. Acceptance of Terms',
                  'By accessing and using the Library Student App, you accept and agree to be bound by the terms and provisions of this agreement. If you do not agree to abide by these terms, please do not use this application.'),
              _section('2. User Conduct',
                  'You agree to use the application only for lawful purposes. You are prohibited from violating or attempting to violate the security of the app, including accessing data not intended for you or logging into a server or account you are not authorized to access.'),
              _section('3. Library Rules',
                  'As a user of this application, you are also bound by the rules and regulations set by the library you join through the app. Failure to comply with the library\'s rules may result in termination of your access to the app.'),
              _section('4. Disclaimer of Warranties',
                  'The application is provided "as is". We make no warranties, expressed or implied, and hereby disclaim and negate all other warranties, including without limitation, implied warranties or conditions of merchantability, fitness for a particular purpose, or non-infringement of intellectual property or other violation of rights.'),
              _section('5. Limitation of Liability',
                  'In no event shall the app developers or its suppliers be liable for any damages (including, without limitation, damages for loss of data or profit, or due to business interruption) arising out of the use or inability to use the application.'),
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
