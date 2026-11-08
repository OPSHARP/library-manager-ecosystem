import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';

/// Help & Support Screen
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final faqs = [
      _FaqItem('How do I add a new student?', 'Go to Students tab, tap the + button, fill in the student details and tap Add Student.'),
      _FaqItem('How do I mark attendance?', 'Go to Attendance tab, tap the toggle next to each student or use the QR scanner.'),
      _FaqItem('How do I record a fee payment?', 'Go to Fees tab, tap Record Payment, enter the details and confirm.'),
      _FaqItem('Is this app free?', 'Library Manager and Owner is a one-time paid app on the Google Play Store. There are no subscriptions or in-app purchases.'),
      _FaqItem('Can I export reports?', 'Yes! Go to Reports, tap the PDF or Excel icon next to any report.'),
      _FaqItem('How do I add staff members?', 'Go to Settings > Staff Management, tap + to invite staff with their role.'),
    ];

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
                    Text('Help & Support', style: AppTypography.headlineSmall),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    const SizedBox(height: 8),

                    // Contact card — in-app support tickets
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: AppGradients.neonPurpleBlue,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.support_agent_rounded,
                              color: Colors.white, size: 40),
                          const SizedBox(height: 12),
                          Text('Need Help?',
                              style: AppTypography.titleMedium
                                  .copyWith(color: Colors.white)),
                          const SizedBox(height: 4),
                          Text('Submit a support ticket and we\'ll respond',
                              style: AppTypography.bodySmall
                                  .copyWith(color: Colors.white70)),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: () => context.push(AppRoutes.createTicket),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.chat_rounded,
                                          size: 20, color: Colors.white),
                                      const SizedBox(width: 8),
                                      Text('New Ticket',
                                          style: AppTypography.labelLarge
                                              .copyWith(color: Colors.white)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: () => context.push(AppRoutes.myTickets),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.inbox_rounded,
                                          size: 20, color: Colors.white),
                                      const SizedBox(width: 8),
                                      Text('My Tickets',
                                          style: AppTypography.labelLarge
                                              .copyWith(color: Colors.white)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text('Frequently Asked Questions',
                        style: AppTypography.titleMedium),
                    const SizedBox(height: 14),
                    ...faqs.map((faq) => _FaqTile(faq: faq)),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqItem {
  final String question;
  final String answer;
  const _FaqItem(this.question, this.answer);
}

class _FaqTile extends StatelessWidget {
  final _FaqItem faq;
  const _FaqTile({required this.faq});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(faq.question, style: AppTypography.labelLarge),
          iconColor: AppColors.primary,
          collapsedIconColor: context.textTertiaryColor,
          children: [
            Text(faq.answer,
                style: AppTypography.bodyMedium
                    .copyWith(color: context.textSecondaryColor)),
          ],
        ),
      ),
    );
  }
}
