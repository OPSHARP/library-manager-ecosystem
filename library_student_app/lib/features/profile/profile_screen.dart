import 'package:flutter/cupertino.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/app_update_service.dart';
import '../auth/presentation/providers/auth_provider.dart';
import '../dashboard/presentation/providers/dashboard_provider.dart';

/// Bottom clearance so the floating tab bar never covers the last row.
const double _tabBarClearance = 112;

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final params = (ownerUid: auth.ownerUid ?? '', studentId: auth.studentUniqueId ?? '');
    final dashboard = ref.watch(dashboardProvider(params));
    final student = dashboard.student;
    final library = dashboard.library;
    final workingHours =
        library?.workingHours ?? {'open': '09:00', 'close': '22:00'};
    final contactNumber = library?.contactNumber;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.systemGroupedBackground,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: _tabBarClearance),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Profile',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: AppColors.label,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildProfileHeader(auth, student),
              ),
              const SizedBox(height: 20),
              CupertinoListSection(
                header: const Text('Account'),
                children: [
                  CupertinoListTile(
                    leading: const _TileIcon(
                      CupertinoIcons.pencil,
                      AppColors.systemBlue,
                    ),
                    title: const Text('Edit Profile'),
                    subtitle: const Text('Update name, phone and address'),
                    trailing: const Icon(
                      CupertinoIcons.chevron_right,
                      size: 16,
                      color: AppColors.tertiaryLabel,
                    ),
                    onTap: () => context.push('/profile-edit'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              CupertinoListSection(
                header: const Text('Student Details'),
                children: [
                  _detailRow('Student ID', auth.studentUniqueId ?? '-'),
                  _detailRow('Name', auth.name ?? student?.name ?? '-'),
                  _detailRow('Phone', student?.phone ?? auth.mobile ?? '-'),
                  _detailRow('Parent Phone', auth.parentMobile ?? '-'),
                  _detailRow('Address', auth.address ?? student?.address ?? '-'),
                  _detailRow('Status', student?.isActive == true ? 'Active' : 'Inactive'),
                  _detailRow('Seat', student?.seatNumber ?? 'Not assigned'),
                ],
              ),
              const SizedBox(height: 20),
              CupertinoListSection(
                header: const Text('Library Info'),
                children: [
                  _detailRow('Library', auth.libraryName ?? '-'),
                  _detailRow('Address', library?.address ?? '-'),
                  _detailRow('Contact', library?.contactNumber ?? '-'),
                  _detailRow('Open', workingHours['open'] ?? '09:00'),
                  _detailRow('Close', workingHours['close'] ?? '22:00'),
                  _detailRow('Capacity', '${library?.seatCapacity ?? '-'} seats'),
                ],
              ),
              const SizedBox(height: 20),
              CupertinoListSection(
                header: const Text('Support'),
                children: [
                  if (contactNumber is String && contactNumber.isNotEmpty)
                    CupertinoListTile(
                      leading: const _TileIcon(
                        CupertinoIcons.phone_fill,
                        AppColors.systemGreen,
                      ),
                      title: const Text('Call Support'),
                      subtitle: Text(contactNumber),
                      trailing: const Icon(
                        CupertinoIcons.chevron_right,
                        size: 16,
                        color: AppColors.tertiaryLabel,
                      ),
                      onTap: () async {
                        final uri = Uri.parse('tel:$contactNumber');
                        if (await canLaunchUrl(uri)) await launchUrl(uri);
                      },
                    ),
                  CupertinoListTile(
                    leading: const _TileIcon(
                      CupertinoIcons.shield_lefthalf_fill,
                      AppColors.systemBlue,
                    ),
                    title: const Text('Privacy Policy'),
                    trailing: const Icon(
                      CupertinoIcons.chevron_right,
                      size: 16,
                      color: AppColors.tertiaryLabel,
                    ),
                    onTap: () => context.push('/privacy'),
                  ),
                  CupertinoListTile(
                    leading: const _TileIcon(
                      CupertinoIcons.doc_text_fill,
                      AppColors.systemIndigo,
                    ),
                    title: const Text('Terms of Use'),
                    trailing: const Icon(
                      CupertinoIcons.chevron_right,
                      size: 16,
                      color: AppColors.tertiaryLabel,
                    ),
                    onTap: () => context.push('/terms'),
                  ),
                  CupertinoListTile(
                    leading: const _TileIcon(
                      CupertinoIcons.info_circle_fill,
                      AppColors.systemPurple,
                    ),
                    title: const Text('App Version'),
                    subtitle: const Text(
                      'Tap to check for updates',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryLabel,
                      ),
                    ),
                    trailing: Text(
                      'v${AppConstants.appVersion}',
                      style: const TextStyle(
                        color: AppColors.secondaryLabel,
                        fontSize: 14,
                      ),
                    ),
                    onTap: () => AppUpdateService.instance.checkForUpdate(
                      userInitiated: true,
                    ),
                  ),
                ],
              ),
              if (auth.hasLibrary) ...[
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: auth.leaveRequestPending
                        ? null
                        : () => _showLeaveDialog(context, ref),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: auth.leaveRequestPending
                            ? AppColors.systemGray4.withValues(alpha: 0.4)
                            : AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            auth.leaveRequestPending
                                ? CupertinoIcons.hourglass
                                : CupertinoIcons.square_arrow_right,
                            color: auth.leaveRequestPending
                                ? AppColors.tertiaryLabel
                                : AppColors.warning,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            auth.leaveRequestPending
                                ? 'Leave Request Pending'
                                : 'Request Library Leave',
                            style: TextStyle(
                              color: auth.leaveRequestPending
                                  ? AppColors.tertiaryLabel
                                  : AppColors.warning,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => _showLogoutDialog(context, ref),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.clear_circled,
                          color: AppColors.error,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Logout',
                          style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(dynamic auth, dynamic student) {
    return GlassContainer(
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.systemBlue, AppColors.systemPurple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              (auth.name ?? student?.name ?? 'S').substring(0, 1).toUpperCase(),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: CupertinoColors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  auth.name ?? student?.name ?? 'Student',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: AppColors.label,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  auth.studentUniqueId ?? '-',
                  style: const TextStyle(
                    color: AppColors.secondaryLabel,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return CupertinoListTile(
      title: Text(
        label,
        style: const TextStyle(fontSize: 15, color: AppColors.label),
      ),
      trailing: Text(
        value,
        style: const TextStyle(fontSize: 15, color: AppColors.secondaryLabel),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  void _showLeaveDialog(BuildContext context, WidgetRef ref) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Request Library Leave'),
        content: const Text(
            'The library owner must approve your leave request before you leave. You can keep using the library until then. Continue?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              final error = await ref
                  .read(authProvider.notifier)
                  .requestLibraryLeave();
              if (!context.mounted) return;
              if (error == null) {
                _showLeaveSentNotice(context);
              } else {
                _showLeaveError(context, error);
              }
            },
            child: const Text('Send Request'),
          ),
        ],
      ),
    );
  }

  void _showLeaveSentNotice(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Leave Request Sent'),
        content: const Text(
            'Your leave request has been sent to the library owner. You will leave the library once they approve it.'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/dashboard');
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showLeaveError(BuildContext context, String error) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Could Not Send Request'),
        content: Text(error),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).logout();
              context.go('/auth');
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class _TileIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _TileIcon(this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 16),
    );
  }
}
