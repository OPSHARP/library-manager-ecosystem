import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/constants/currency_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../app/router.dart';
import '../../../subscription/presentation/providers/subscription_provider.dart';
import '../../../../core/services/backup_service.dart';
import '../../../../core/services/biometric_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../library_setup/data/models/library_model.dart';
import '../../../library_setup/data/repositories/library_repository.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../providers/settings_provider.dart';

/// Settings Screen
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
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
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context)!.settings,
                      style: AppTypography.headlineSmall,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [


                    // Subscription Card (1. Upgrade to Pro)
                    ref.watch(subscriptionStatusProvider) ==
                            SubscriptionStatus.active
                        ? _buildSubscriptionActiveTile(context, ref)
                        : _buildSubscriptionUpgradeTile(context, ref),

                    const SizedBox(height: 24),

                    // 2. Library Setup
                    _SettingsTile(
                      icon: Icons.local_library_rounded,
                      title: 'Library Setup',
                      color: AppColors.primary,
                      number: '2',
                      onTap: () => context.push(AppRoutes.librarySetup),
                    ),

                    // 3. Your Library Code
                    _buildLibraryCodeTile(context, ref, number: '3'),

                    // Admin Panel (only for admin set in Firestore)
                    if (ref.watch(isAdminSyncProvider)) ...[
                      GestureDetector(
                        onTap: () => context.push(AppRoutes.adminPanel),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.admin_panel_settings_rounded,
                                  size: 22,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Admin Panel',
                                      style: AppTypography.labelLarge.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Manage all support tickets',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.white70,
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    _SectionTitle('General'),
                    _SettingsTile(
                      icon: Icons.language_rounded,
                      title: AppLocalizations.of(context)!.language,
                      color: AppColors.secondary,
                      subtitle: settings.language,
                      onTap: () => _showLanguagePicker(context, ref),
                    ),
                    _SettingsTile(
                      icon: Icons.attach_money_rounded,
                      title: 'Currency',
                      color: AppColors.accent,
                      subtitle:
                          '${settings.currencySymbol} ${settings.currencyCode}',
                      onTap: () => _showCurrencyPicker(context, ref),
                    ),
                    _SettingsTile(
                      icon: Icons.notifications_rounded,
                      title: AppLocalizations.of(context)!.notifications,
                      color: AppColors.warning,
                      trailing: Switch(
                        value: settings.notificationsEnabled,
                        onChanged: (_) => ref
                            .read(settingsProvider.notifier)
                            .toggleNotifications(),
                      ),
                    ),

                    const SizedBox(height: 16),
                    _SectionTitle('Library'),
                    _SettingsTile(
                      icon: Icons.local_library_rounded,
                      title: 'Library Setup',
                      color: AppColors.primary,
                      onTap: () => context.push(AppRoutes.librarySetup),
                    ),
                    _SettingsTile(
                      icon: Icons.chair_rounded,
                      title: 'Seat Settings',
                      color: AppColors.accent,
                      onTap: () => context.push(AppRoutes.librarySettings),
                    ),
                    _SettingsTile(
                      icon: Icons.receipt_long_rounded,
                      title: 'Fee Structure',
                      color: AppColors.neonPink,
                      onTap: () => context.push(AppRoutes.librarySettings),
                    ),
                    _SettingsTile(
                      icon: Icons.schedule_rounded,
                      title: 'Working Hours',
                      color: AppColors.secondary,
                      onTap: () => context.push(AppRoutes.librarySettings),
                    ),
                    _SettingsTile(
                      icon: Icons.people_rounded,
                      title: 'Staff Management',
                      color: AppColors.neonPurple,
                      onTap: () => context.push(AppRoutes.staff),
                    ),
                    const SizedBox(height: 16),
                    _SectionTitle('Data & Backup'),
                    _SettingsTile(
                      icon: Icons.backup_rounded,
                      title: 'Backup Data',
                      color: AppColors.accent,
                      onTap: () async {
                        try {
                          final user = ref.read(currentUserProvider);
                          if (user == null) return;
                          await BackupService.instance.shareBackup(user.uid);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Backup exported successfully'),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Backup failed: $e')),
                            );
                          }
                        }
                      },
                    ),
                    _SettingsTile(
                      icon: Icons.restore_rounded,
                      title: 'Restore Data',
                      color: AppColors.primary,
                      onTap: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['json'],
                        );
                        if (result == null ||
                            result.files.single.path == null) {
                          return;
                        }
                        if (!context.mounted) return;
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: context.surfaceColor,
                            title: const Text('Restore Backup'),
                            content: const Text(
                              'This will replace ALL current data with the backup. This cannot be undone. Continue?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: Text(
                                  'Restore',
                                  style: TextStyle(color: AppColors.error),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirm != true) return;
                        final user = ref.read(currentUserProvider);
                        if (user == null) return;
                        final err = await BackupService.instance.importBackup(
                          user.uid,
                          result.files.single.path!,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                err ??
                                    'Data restored successfully. Restart the app to see changes.',
                              ),
                            ),
                          );
                        }
                      },
                    ),

                    const SizedBox(height: 16),
                    const SizedBox(height: 16),
                    const _SectionTitle('Security'),
                    const _BiometricLockTile(),

                    const SizedBox(height: 16),
                    _SectionTitle(AppLocalizations.of(context)!.about),
                    _SettingsTile(
                      icon: Icons.help_rounded,
                      title: AppLocalizations.of(context)!.helpSupport,
                      color: AppColors.secondary,
                      onTap: () => context.push(AppRoutes.help),
                    ),
                    _SettingsTile(
                      icon: Icons.description_rounded,
                      title: AppLocalizations.of(context)!.termsPrivacy,
                      color: context.textTertiaryColor,
                      onTap: () => context.push(AppRoutes.terms),
                    ),

                    const SizedBox(height: 16),
                    // Logout
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () async {
                            await ref.read(authProvider.notifier).logout();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.logout_rounded,
                                  color: AppColors.warning,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  AppLocalizations.of(context)!.logout,
                                  style: AppTypography.labelLarge.copyWith(
                                    color: AppColors.warning,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Delete Account
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _showDeleteAccountDialog(context, ref),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.delete_forever_rounded,
                                  color: AppColors.error,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Delete Account',
                                  style: AppTypography.labelLarge.copyWith(
                                    color: AppColors.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Subscription active tile — shows current plan status.
  Widget _buildSubscriptionActiveTile(BuildContext context, WidgetRef ref) {
    final sub = ref.watch(currentSubscriptionProvider);
    return GestureDetector(
      onTap: () => context.push(AppRoutes.subscription),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: AppGradients.primaryGradient,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                size: 22,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: const Text('1',
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sub.planName,
                    style: AppTypography.labelLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap to manage',
                    style: AppTypography.bodySmall.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white70,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  /// Subscription upgrade tile — encourages the user to subscribe.
  Widget _buildSubscriptionUpgradeTile(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.subscription),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.star_rounded,
                size: 22,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: const Text('1',
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Upgrade to Pro',
                    style: AppTypography.labelLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Unlock all premium features',
                    style: AppTypography.bodySmall.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white70,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLibraryCodeTile(BuildContext context, WidgetRef ref, {String? number}) {
    final user = ref.watch(currentUserProvider);
    final uid = user?.uid;
    return FutureBuilder<LibraryModel?>(
      future: uid != null
          ? LibraryRepository(FirestoreService(uid: uid)).getLibrarySync('lib_$uid')
          : Future.value(null),
      builder: (ctx, snap) {
        final code = snap.data?.libraryCode;
        final qrData = snap.data?.qrData;
        if (code == null && qrData == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: GestureDetector(
            onTap: () => _showLibraryQrDialog(context, code ?? '', qrData ?? ''),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.qr_code_rounded, size: 22, color: Colors.white),
                      ),
                      if (number != null)
                        Positioned(
                          top: -5,
                          right: -5,
                          child: Container(
                            width: 18,
                            height: 18,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Text(number,
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                )),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Library Code', style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(code != null ? 'Code: $code' : 'Tap to see QR',
                          style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 22),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showLibraryQrDialog(BuildContext context, String code, String qrData) {
    final qrContent = qrData.isNotEmpty ? qrData : '{"libraryCode":"$code"}';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Library QR Code',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SizedBox(
                  width: 220,
                  height: 220,
                  child: QrImageView(
                    data: qrContent,
                    version: QrVersions.auto,
                    size: 220,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                    dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.vpn_key_rounded, color: Color(0xFF4F46E5), size: 18),
                    const SizedBox(width: 8),
                    Text(code, style: const TextStyle(
                      color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 3)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text('Students scan this QR or enter the code above to join',
                  style: TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: AppTypography.labelMedium.copyWith(
          color: context.textTertiaryColor,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String? number;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.color,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.number,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap ?? () {},
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                if (number != null) ...[
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      number!,
                      style: AppTypography.badge.copyWith(color: color),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTypography.labelLarge),
                      if (subtitle != null)
                        Text(subtitle!, style: AppTypography.bodySmall),
                    ],
                  ),
                ),
                trailing ??
                    Icon(
                      Icons.chevron_right_rounded,
                      color: context.textTertiaryColor,
                      size: 22,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
  final controller = TextEditingController();
  showDialog(
    context: context,
    builder: (ctx) {
      var isConfirmed = false;
      return StatefulBuilder(
        builder: (ctx, setInnerState) => AlertDialog(
          backgroundColor: context.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AppColors.error,
                size: 28,
              ),
              const SizedBox(width: 10),
              Text(
                'Delete Account',
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will permanently delete your account and ALL data. '
                'After deletion, you will NOT be able to log back in with this account.',
                style: AppTypography.bodyMedium.copyWith(
                  color: context.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_rounded, color: AppColors.error, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'All students, staff, seats, attendance, fees, books, '
                        'notifications, and library settings will be lost forever.',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Type DELETE to confirm:',
                style: AppTypography.labelLarge.copyWith(
                  color: context.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'DELETE',
                  hintStyle: TextStyle(
                    color: context.textTertiaryColor.withValues(alpha: 0.5),
                  ),
                  filled: true,
                  fillColor: context.cardBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: context.textTertiaryColor.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.error),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                style: AppTypography.bodyMedium,
                autofocus: true,
                onChanged: (v) =>
                    setInnerState(() => isConfirmed = v == 'DELETE'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: TextStyle(color: context.textSecondaryColor),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                disabledBackgroundColor: AppColors.error.withValues(alpha: 0.4),
              ),
              onPressed: isConfirmed
                  ? () async {
                      Navigator.pop(ctx);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Deleting account...')),
                      );
                      await ref.read(authProvider.notifier).deleteAccount();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Account deleted successfully.'),
                          ),
                        );
                      }
                    }
                  : null,
              child: const Text('Delete Permanently'),
            ),
          ],
        ),
      );
    },
  );
}

void _showCurrencyPicker(BuildContext context, WidgetRef ref) {
  final current = ref.read(settingsProvider).currencyCode;

  showModalBottomSheet(
    context: context,
    backgroundColor: context.surfaceColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.textTertiaryColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text('Select Currency', style: AppTypography.headlineMedium),
          const SizedBox(height: 16),
          SizedBox(
            height: 400,
            child: ListView.builder(
              itemCount: kCurrencies.length,
              itemBuilder: (ctx, i) {
                final c = kCurrencies[i];
                final isSelected = c['code'] == current;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      ref
                          .read(settingsProvider.notifier)
                          .setCurrency(c['symbol']!, c['code']!, c['locale']!);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : null,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 48,
                            child: Text(
                              c['symbol']!,
                              style: AppTypography.titleMedium.copyWith(
                                color: isSelected
                                    ? AppColors.primary
                                    : context.textPrimaryColor,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c['name']!,
                                  style: AppTypography.labelLarge.copyWith(
                                    color: isSelected
                                        ? AppColors.primary
                                        : context.textPrimaryColor,
                                  ),
                                ),
                                Text(
                                  c['code']!,
                                  style: AppTypography.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

void _showLanguagePicker(BuildContext context, WidgetRef ref) {
  final languages = [
    {'name': 'English', 'code': 'en'},
    {'name': 'Hindi', 'code': 'hi'},
    {'name': 'Spanish', 'code': 'es'},
    {'name': 'French', 'code': 'fr'},
    {'name': 'Arabic', 'code': 'ar'},
    {'name': 'Portuguese', 'code': 'pt'},
    {'name': 'Chinese', 'code': 'zh'},
    {'name': 'Japanese', 'code': 'ja'},
    {'name': 'Korean', 'code': 'ko'},
    {'name': 'Turkish', 'code': 'tr'},
    {'name': 'Russian', 'code': 'ru'},
    {'name': 'German', 'code': 'de'},
    {'name': 'Vietnamese', 'code': 'vi'},
    {'name': 'Thai', 'code': 'th'},
    {'name': 'Malay', 'code': 'ms'},
  ];

  final current = ref.read(settingsProvider).language;

  showModalBottomSheet(
    context: context,
    backgroundColor: context.surfaceColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.textTertiaryColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text('Select Language', style: AppTypography.headlineMedium),
          const SizedBox(height: 16),
          SizedBox(
            height: 400,
            child: ListView.builder(
              itemCount: languages.length,
              itemBuilder: (ctx, i) {
                final lang = languages[i];
                final isSelected = lang['name'] == current;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      ref
                          .read(settingsProvider.notifier)
                          .setLanguage(lang['name']!);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : null,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              lang['name']!,
                              style: AppTypography.labelLarge.copyWith(
                                color: isSelected
                                    ? AppColors.primary
                                    : context.textPrimaryColor,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}




class _BiometricLockTile extends StatefulWidget {
  const _BiometricLockTile();

  @override
  State<_BiometricLockTile> createState() => _BiometricLockTileState();
}

class _BiometricLockTileState extends State<_BiometricLockTile> {
  bool _enabled = false;
  bool _isAvailable = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final available = await BiometricService.instance.isAvailable();
    final enabled = await BiometricService.instance.isBiometricEnabled();
    if (mounted) {
      setState(() {
        _isAvailable = available;
        _enabled = enabled;
        _loading = false;
      });
    }
  }

  Future<void> _toggle(bool val) async {
    if (!_isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Biometrics or Device Lock not available on this device.'),
        ),
      );
      return;
    }

    final success = await BiometricService.instance.authenticate(
      reason: val
          ? 'Authenticate to enable App Lock'
          : 'Authenticate to disable App Lock',
    );

    if (success) {
      await BiometricService.instance.setBiometricEnabled(val);
      if (mounted) {
        setState(() => _enabled = val);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(val ? 'App Lock enabled' : 'App Lock disabled'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    return _SettingsTile(
      icon: Icons.fingerprint_rounded,
      title: 'App Lock (Biometrics & PIN)',
      subtitle: _enabled ? 'Enabled' : 'Disabled',
      color: AppColors.secondary,
      trailing: Switch.adaptive(
        value: _enabled,
        onChanged: _toggle,
        activeTrackColor: AppColors.primary,
        activeThumbColor: Colors.white,
      ),
      onTap: () => _toggle(!_enabled),
    );
  }
}
