import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/stat_card.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../../core/widgets/email_verification_banner.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../notifications/notifications_screen.dart';
import '../providers/dashboard_provider.dart';
import '../providers/notices_provider.dart';

/// One-shot guard so the "you are now joined" dialog shows only once per run.
bool _joinDialogShown = false;

/// Bottom clearance so the floating tab bar never covers the last card or the
/// ad strip.
const double _tabBarClearance = 112;

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final params = (ownerUid: auth.ownerUid ?? '', studentId: auth.studentUniqueId ?? '');
    final dashboard = ref.watch(dashboardProvider(params));
    final student = dashboard.student;

    // LIVE case: the owner accepted while the app is open — reload the record
    // and announce the join.
    ref.listen(authProvider, (prev, next) {
      if (prev != null &&
          prev.requestPending &&
          !next.requestPending &&
          next.isVerifiedStudent &&
          next.hasLibrary) {
        ref.read(authProvider.notifier).markJoined();
        ref.read(dashboardProvider(params).notifier).refresh();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) _announceJoin(context, next.libraryName);
        });
      }
    });

    // Owner kicked the student while the app was open → auto-leave + notice.
    ref.listen(authProvider, (prev, next) {
      if (prev != null && !prev.kicked && next.kicked && next.kickMessage != null) {
        ref.read(authProvider.notifier).acknowledgeKick();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            showCupertinoDialog(
              context: context,
              builder: (ctx) => CupertinoAlertDialog(
                title: const Text('Removed'),
                content: Text(next.kickMessage!),
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
        });
      }
    });

    // RESTART case: session still says pending but the owner already accepted.
    if (auth.requestPending && student != null && !_joinDialogShown) {
      _joinDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(authProvider.notifier).markJoined();
        if (context.mounted) _announceJoin(context, auth.libraryName);
      });
    }

    return CupertinoPageScaffold(
      backgroundColor: AppColors.systemGroupedBackground,
      child: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                _buildNavBar(auth, params, ref),
                const SliverToBoxAdapter(child: EmailVerificationBanner()),
                CupertinoSliverRefreshControl(
                  onRefresh: () async {
                    // Pull-to-refresh re-verifies membership against Firestore
                    // (the owner may have kicked/removed this student while the
                    // app was in the background) BEFORE reloading the dashboard.
                    await ref.read(authProvider.notifier).verifyMembership();
                    await ref
                        .read(dashboardProvider(params).notifier)
                        .refresh();
                  },
                ),
                if (!auth.hasLibrary)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildNoLibrary(context),
                  )
                else if (dashboard.isLoading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: LoadingWidget(message: 'Loading your profile…'),
                  )
                else if (dashboard.error != null)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildError(dashboard.error!, params, ref),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate(
                        _buildContentList(context, dashboard, ref),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: _tabBarClearance),
        ],
      ),
    );
  }

  CupertinoSliverNavigationBar _buildNavBar(
      AuthState auth, DashboardParams params, WidgetRef ref) {
    final title = auth.libraryName ?? 'Students Portal';
    return CupertinoSliverNavigationBar(
      largeTitle: Text(title, overflow: TextOverflow.ellipsis),
      leading: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => ref.context.push('/qr-scanner'),
        child: const Icon(CupertinoIcons.qrcode_viewfinder),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (auth.hasLibrary)
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () async {
                await ref.read(authProvider.notifier).verifyMembership();
                await ref
                    .read(dashboardProvider(params).notifier)
                    .refresh();
              },
              child: const Icon(CupertinoIcons.refresh),
            ),
          const SizedBox(width: 4),
          Stack(
            clipBehavior: Clip.none,
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                child: const Icon(CupertinoIcons.bell),
                onPressed: () => ref.context.push('/notifications'),
              ),
              Positioned(
                right: 4,
                top: 4,
                child: Consumer(builder: (_, ref, _) {
                  final count = ref.watch(unreadNotificationCountProvider);
                  if (count == 0) return const SizedBox.shrink();
                  return Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildContentList(
      BuildContext context, DashboardState state, WidgetRef ref) {
    final student = state.student;
    final library = state.library;
    final authState = ref.watch(authProvider);

    return [
      if (authState.leaveRequestPending) ...[
        _buildLeavePendingBanner(context),
        const SizedBox(height: 12),
      ],
      _buildWelcomeCard(student, authState.name),
      const SizedBox(height: 12),
      _buildNoticeBoard(context, ref),
      _buildSeatsOverview(context, state),
      if (student != null) ...[
        const SizedBox(height: 12),
        _buildAvailableBooks(context, state),
        const SizedBox(height: 12),
        _buildQuickStats(state),
        const SizedBox(height: 12),
        _buildSeatInfo(context, state),
        const SizedBox(height: 12),
        _buildBooksSummary(context, state),
        const SizedBox(height: 12),
        _buildFeesSummary(context, state),
        const SizedBox(height: 12),
        _buildAttendanceSummary(context, state),
      ] else ...[
        if (authState.requestPending) ...[
          const SizedBox(height: 12),
          _buildJoinRequestPendingCard(context, authState),
        ],
        const SizedBox(height: 12),
        _buildLinkStudentIdCard(context, ref),
      ],
      const SizedBox(height: 12),
      _buildSupportCard(authState.libraryPhone ?? library?.contactNumber),
      const SizedBox(height: 12),
      _buildLibraryInfoCard(library, authState),
      const SizedBox(height: 24),
    ];
  }

  void _announceJoin(BuildContext context, String? libraryName) {
    if (_joinDialogShown) return;
    _joinDialogShown = true;
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Welcome!'),
        content: Text('You are now joined "${libraryName ?? 'Library'}"'),
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

  Widget _buildLeavePendingBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(CupertinoIcons.hourglass, color: AppColors.warning, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Leave request pending — waiting for the owner to approve.',
              style: TextStyle(color: AppColors.label, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoLibrary(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                color: AppColors.systemGray5,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.building_2_fill,
                size: 36,
                color: AppColors.tertiaryLabel,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Library Joined',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.label,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Join a library to see your seat, books, fees and attendance here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: AppColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton.filled(
                borderRadius: BorderRadius.circular(14),
                padding: const EdgeInsets.symmetric(vertical: 13),
onPressed: () => context.push('/qr-scanner'),
                child: const Text(
                  'Scan QR Code to Join',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => context.push('/nearby-libraries'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.systemBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Find Libraries Nearby',
                    style: TextStyle(
                      color: AppColors.systemBlue,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String error, DashboardParams params, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.cloud_download,
              size: 56,
              color: AppColors.tertiaryLabel,
            ),
            const SizedBox(height: 16),
            Text(
              error,
              style: const TextStyle(
                color: AppColors.secondaryLabel,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            CupertinoButton.filled(
              borderRadius: BorderRadius.circular(12),
              onPressed: () async {
                await ref.read(authProvider.notifier).verifyMembership();
                await ref
                    .read(dashboardProvider(params).notifier)
                    .refresh();
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.refresh),
                  SizedBox(width: 8),
                  Text('Retry'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Card primitives ───

  Widget _cardHeader(IconData icon, Color color, String title,
      {Widget? trailing}) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 17),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.label,
              letterSpacing: -0.2,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }

  Widget _outlineButton(String label, VoidCallback onPressed,
      {IconData? icon}) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.systemBlue.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) Icon(icon, size: 16, color: AppColors.systemBlue),
            if (icon != null) const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.systemBlue,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _smallStat(String label, String value, Color color, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: AppColors.secondaryLabel, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.secondaryLabel),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: AppColors.label, fontSize: 14),
          ),
        ),
      ],
    );
  }

  // ─── Cards ───

  Widget _buildWelcomeCard(dynamic student, String? name) {
    return GlassContainer(
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.systemBlue, AppColors.systemPurple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: const Icon(
              CupertinoIcons.person_solid,
              color: CupertinoColors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome back,',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.secondaryLabel,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name ?? student?.name ?? 'Student',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: AppColors.label,
                    letterSpacing: -0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _chip(
            student?.isActive == true ? 'Active' : 'Inactive',
            student?.isActive == true ? AppColors.success : AppColors.error,
            student?.isActive == true ? AppColors.successBg : AppColors.errorBg,
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeBoard(BuildContext context, WidgetRef ref) {
    final noticesAsync = ref.watch(studentNoticesProvider);
    return noticesAsync.when(
      data: (notices) {
        final activeNotices = notices.where((n) => n['isActive'] != false).toList();
        if (activeNotices.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _cardHeader(
                  CupertinoIcons.bell_fill,
                  AppColors.warning,
                  'Notice Board',
                  trailing: _chip(
                    '${activeNotices.length} Notice${activeNotices.length > 1 ? 's' : ''}',
                    AppColors.warning,
                    AppColors.warning.withValues(alpha: 0.14),
                  ),
                ),
                const SizedBox(height: 12),
                ...activeNotices.take(3).map((notice) {
                  final priority = (notice['priority'] ?? 'normal').toString().toLowerCase();
                  final title = (notice['title'] ?? 'Notice').toString();
                  final message = (notice['message'] ?? '').toString();

                  Color tagColor;
                  Color tagBg;
                  String tagText;
                  if (priority == 'urgent') {
                    tagColor = CupertinoColors.destructiveRed;
                    tagBg = CupertinoColors.destructiveRed.withValues(alpha: 0.15);
                    tagText = 'URGENT';
                  } else if (priority == 'important') {
                    tagColor = AppColors.warning;
                    tagBg = AppColors.warning.withValues(alpha: 0.15);
                    tagText = 'IMPORTANT';
                  } else {
                    tagColor = AppColors.systemBlue;
                    tagBg = AppColors.systemBlue.withValues(alpha: 0.12);
                    tagText = 'ANNOUNCEMENT';
                  }

                  DateTime? date;
                  final rawCreatedAt = notice['createdAt'];
                  if (rawCreatedAt is Timestamp) {
                    date = rawCreatedAt.toDate();
                  } else if (rawCreatedAt is String) {
                    date = DateTime.tryParse(rawCreatedAt);
                  }

                  final dateStr = date != null ? DateFormat('dd MMM, hh:mm a').format(date) : '';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: AppColors.systemGroupedBackground.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: priority == 'urgent'
                            ? CupertinoColors.destructiveRed.withValues(alpha: 0.3)
                            : AppColors.separator.withValues(alpha: 0.3),
                      ),
                    ),
                    child: CupertinoButton(
                      padding: const EdgeInsets.all(12),
                      onPressed: () => _showNoticeDetails(context, notice, tagText, tagColor, dateStr),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _chip(tagText, tagColor, tagBg),
                              const Spacer(),
                              if (dateStr.isNotEmpty)
                                Text(
                                  dateStr,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.tertiaryLabel,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.label,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (message.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              message,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.secondaryLabel,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  void _showNoticeDetails(BuildContext context, Map<String, dynamic> notice,
      String tagText, Color tagColor, String dateStr) {
    final title = (notice['title'] ?? 'Notice').toString();
    final message = (notice['message'] ?? '').toString();

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoPopupSurface(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          color: AppColors.secondarySystemGroupedBackground,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.systemGray4,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: tagColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tagText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: tagColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (dateStr.isNotEmpty)
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.tertiaryLabel,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.label,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Text(
                    message,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      color: AppColors.label,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  borderRadius: BorderRadius.circular(12),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Dismiss'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeatsOverview(BuildContext context, DashboardState state) {
    final categories = state.seatCategories;
    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            CupertinoIcons.rectangle_grid_1x2_fill,
            AppColors.systemBlue,
            'Library Seats',
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => context.push('/seat-layout'),
              child: const Text(
                'Layout',
                style: TextStyle(color: AppColors.systemBlue, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.infoBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${state.totalSeats}',
                        style: const TextStyle(
                          color: AppColors.systemBlue,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Total',
                        style: TextStyle(
                          color: AppColors.secondaryLabel,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.successBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${state.freeSeats}',
                        style: const TextStyle(
                          color: AppColors.success,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Free',
                        style: TextStyle(
                          color: AppColors.secondaryLabel,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (categories.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.map((cat) {
                final count =
                    state.allSeats.where((s) => s.category == cat).length;
                return _chip(
                  '$cat ($count)',
                  AppColors.systemIndigo,
                  AppColors.systemIndigo.withValues(alpha: 0.14),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 12),
          _outlineButton(
            'View Seat Layout',
            () => context.push('/seat-layout'),
            icon: CupertinoIcons.square_grid_2x2,
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableBooks(BuildContext context, DashboardState state) {
    final available = state.availableBooks;
    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            CupertinoIcons.book_fill,
            AppColors.systemCyan,
            'Available Books',
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => context.push('/books'),
              child: const Text(
                'Browse',
                style: TextStyle(color: AppColors.systemBlue, fontSize: 13),
              ),
            ),
          ),
          if (available.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'No books available right now',
                style: TextStyle(color: AppColors.tertiaryLabel),
              ),
            )
          else ...[
            const SizedBox(height: 4),
            ...available.take(4).map((book) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(
                        CupertinoIcons.book,
                        size: 16,
                        color: AppColors.tertiaryLabel,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          book.title,
                          style: const TextStyle(
                            color: AppColors.label,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        book.author,
                        style: const TextStyle(
                          color: AppColors.secondaryLabel,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )),
            if (available.length > 4)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '+${available.length - 4} more',
                  style: const TextStyle(
                    color: AppColors.tertiaryLabel,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildJoinRequestPendingCard(BuildContext context, AuthState auth) {
    final phone = auth.libraryPhone ?? '';
    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _chip('Pending', AppColors.warning, AppColors.warningBg),
          const SizedBox(height: 10),
          Text(
            'Your request to join ${auth.libraryName ?? 'the library'} has been sent.',
            style: const TextStyle(
              color: AppColors.label,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Waiting for the library owner to approve. Until then you can view seats, library location and contact details.',
            style: TextStyle(
              color: AppColors.secondaryLabel,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 12),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _callOwner(context, phone),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.phone_fill,
                    color: AppColors.systemBlue,
                    size: 15,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Contact library owner',
                    style: TextStyle(
                      color: AppColors.systemBlue,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _callOwner(BuildContext context, String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildLinkStudentIdCard(BuildContext context, WidgetRef ref) {
    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            CupertinoIcons.hourglass,
            AppColors.warning,
            'Pending Owner Approval',
          ),
          const SizedBox(height: 10),
          const Text(
            'Your request to join this library has been sent to the owner. You will gain full access to your seat, attendance, and fees once they approve it.',
            style: TextStyle(
              color: AppColors.secondaryLabel,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.warningBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  CupertinoIcons.info_circle_fill,
                  color: AppColors.warning,
                  size: 16,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'You can still view available seats and library contact info below.',
                    style: TextStyle(color: AppColors.warning, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(DashboardState state) {
    return Row(
      children: [
        Expanded(
          child: StatCard(
            label: 'Present',
            value: '${state.presentDays}',
            icon: CupertinoIcons.check_mark_circled_solid,
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StatCard(
            label: 'Missed',
            value: '${state.missedDays}',
            icon: CupertinoIcons.clear_circled_solid,
            color: AppColors.error,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StatCard(
            label: 'Books',
            value: '${state.issuedBooksCount}',
            icon: CupertinoIcons.book_solid,
            color: AppColors.systemBlue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StatCard(
            label: 'Due',
            value: '${state.currency}${state.totalPending.toStringAsFixed(0)}',
            icon: CupertinoIcons.money_dollar_circle_fill,
            color:
                state.totalPending > 0 ? AppColors.warning : AppColors.success,
          ),
        ),
      ],
    );
  }

  Widget _buildSeatInfo(BuildContext context, DashboardState state) {
    final seat = state.assignedSeat;
    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            CupertinoIcons.square_fill,
            AppColors.systemBlue,
            'My Seat',
          ),
          const SizedBox(height: 12),
          if (seat != null) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: seat.isOccupied
                        ? AppColors.errorBg
                        : AppColors.successBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Seat ${seat.seatNumber}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: seat.isOccupied
                          ? AppColors.error
                          : AppColors.success,
                    ),
                  ),
                ),
                const Spacer(),
                _chip(
                  seat.status.toUpperCase(),
                  seat.isOccupied ? AppColors.error : AppColors.success,
                  seat.isOccupied
                      ? AppColors.errorBg
                      : AppColors.successBg,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Category: ${seat.category}',
              style: const TextStyle(
                color: AppColors.secondaryLabel,
                fontSize: 13,
              ),
            ),
          ] else ...[
            const Text(
              'No seat assigned',
              style: TextStyle(color: AppColors.tertiaryLabel),
            ),
          ],
          const SizedBox(height: 12),
          _outlineButton(
            'View All Seats',
            () => context.push('/seat-layout'),
            icon: CupertinoIcons.square_grid_2x2,
          ),
        ],
      ),
    );
  }

  Widget _buildBooksSummary(BuildContext context, DashboardState state) {
    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            CupertinoIcons.book_circle_fill,
            AppColors.systemCyan,
            'My Books',
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => context.push('/books'),
              child: const Text(
                'View All',
                style: TextStyle(color: AppColors.systemBlue, fontSize: 13),
              ),
            ),
          ),
          if (state.books.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'No books issued yet',
                style: TextStyle(color: AppColors.tertiaryLabel),
              ),
            )
          else ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _smallStat(
                  'Issued',
                  '${state.issuedBooksCount}',
                  AppColors.warning,
                  AppColors.warningBg,
                ),
                const SizedBox(width: 12),
                _smallStat(
                  'Returned',
                  '${state.returnedBooksCount}',
                  AppColors.success,
                  AppColors.successBg,
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...state.books.where((b) => b.isIssued).take(2).map((book) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(
                        CupertinoIcons.book,
                        size: 16,
                        color: AppColors.tertiaryLabel,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          book.title,
                          style: const TextStyle(
                            color: AppColors.label,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        book.author,
                        style: const TextStyle(
                          color: AppColors.secondaryLabel,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildFeesSummary(BuildContext context, DashboardState state) {
    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            CupertinoIcons.money_dollar_circle_fill,
            AppColors.systemPink,
            'Fee Status',
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => context.push('/fees'),
              child: const Text(
                'Details',
                style: TextStyle(color: AppColors.systemBlue, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Paid',
                      style: TextStyle(
                        color: AppColors.secondaryLabel,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${state.currency}${state.totalPaid.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppColors.success,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 40, color: AppColors.separator),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Pending',
                      style: TextStyle(
                        color: AppColors.secondaryLabel,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${state.currency}${state.totalPending.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: state.totalPending > 0
                            ? AppColors.warning
                            : AppColors.success,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceSummary(BuildContext context, DashboardState state) {
    final rate = state.totalAttendanceDays > 0
        ? (state.presentDays / state.totalAttendanceDays * 100)
            .toStringAsFixed(1)
        : '0.0';
    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            CupertinoIcons.calendar_circle_fill,
            AppColors.systemGreen,
            'Attendance',
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => context.push('/attendance'),
              child: const Text(
                'View All',
                style: TextStyle(color: AppColors.systemBlue, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _smallStat(
                'Present',
                '${state.presentDays}',
                AppColors.success,
                AppColors.successBg,
              ),
              const SizedBox(width: 12),
              _smallStat(
                'Missed',
                '${state.missedDays}',
                AppColors.error,
                AppColors.errorBg,
              ),
              const SizedBox(width: 12),
              _smallStat(
                'Rate',
                '$rate%',
                AppColors.systemBlue,
                AppColors.infoBg,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLibraryInfoCard(dynamic library, dynamic authState) {
    final address = authState.libraryAddress ?? library?.address ?? '';
    final phone = authState.libraryPhone ?? library?.contactNumber ?? '';
    final libName = authState.libraryName ?? library?.libraryName ?? 'Library';

    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            CupertinoIcons.building_2_fill,
            AppColors.systemPurple,
            'Library Info',
          ),
          const SizedBox(height: 12),
          _infoRow(CupertinoIcons.map_pin_ellipse, libName),
          if (address.isNotEmpty) ...[
            const SizedBox(height: 8),
            _infoRow(CupertinoIcons.location_solid, address),
          ],
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 8),
            _infoRow(CupertinoIcons.phone_fill, phone),
          ],
        ],
      ),
    );
  }

  Widget _buildSupportCard(String? phone) {
    return GlassContainer(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.infoBg,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Icon(
              CupertinoIcons.phone_circle_fill,
              color: AppColors.systemBlue,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Library Support',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.label,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  phone ?? 'Contact library staff',
                  style: TextStyle(
                    color: phone != null
                        ? AppColors.label
                        : AppColors.tertiaryLabel,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          if (phone != null)
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () async {
                final uri = Uri.parse('tel:$phone');
                if (await canLaunchUrl(uri)) await launchUrl(uri);
              },
              child: const Icon(
                CupertinoIcons.phone_fill,
                color: AppColors.success,
              ),
            ),
        ],
      ),
    );
  }
}
