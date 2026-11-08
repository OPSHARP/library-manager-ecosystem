import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/services/navigation.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/auth_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/students/presentation/screens/students_list_screen.dart';
import '../../features/students/presentation/screens/add_student_screen.dart';
import '../../features/students/presentation/screens/student_profile_screen.dart';
import '../../features/students/presentation/screens/import_students_screen.dart';
import '../../features/students/presentation/screens/join_requests_screen.dart';
import '../../features/seats/presentation/screens/seat_management_screen.dart';
import '../../features/seats/presentation/screens/seat_layout_editor_screen.dart';
import '../../features/attendance/presentation/screens/attendance_screen.dart';
import '../../features/fees/presentation/screens/fee_management_screen.dart';
import '../../features/expenses/presentation/screens/expense_list_screen.dart';
import '../../features/notices/presentation/screens/notice_board_screen.dart';
import '../../features/books/presentation/screens/book_management_screen.dart';

import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/notifications/presentation/screens/send_notification_screen.dart';
import '../../features/analytics/presentation/screens/analytics_screen.dart';
import '../../features/reports/presentation/screens/reports_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/profile_screen.dart';
import '../../features/settings/presentation/screens/security_screen.dart';
import '../../features/settings/presentation/screens/library_settings_screen.dart';

import '../../features/staff/presentation/screens/staff_list_screen.dart';
import '../../features/staff/presentation/screens/add_staff_screen.dart';
import '../../features/library_setup/presentation/screens/library_setup_screen.dart';
import '../../features/library_setup/presentation/screens/library_branding_screen.dart';
import '../../features/library_setup/presentation/screens/library_location_screen.dart';
import '../../features/help/presentation/screens/help_screen.dart';
import '../../features/help/presentation/screens/terms_screen.dart';
import '../../features/attendance/presentation/screens/qr_scan_screen.dart';
import '../../features/books/presentation/screens/isbn_scan_screen.dart';
import '../../features/support/presentation/screens/create_ticket_screen.dart';
import '../../features/support/presentation/screens/my_tickets_screen.dart';
import '../../features/support/presentation/screens/ticket_chat_screen.dart';
import '../../features/admin/presentation/screens/admin_panel_screen.dart';
import '../../features/subscription/presentation/screens/subscription_screen.dart';
import '../../features/student_portal/presentation/screens/student_portal_screen.dart';
import '../../features/white_label/presentation/screens/white_label_screen.dart';
import '../core/widgets/bottom_nav_shell.dart';
import '../core/widgets/splash_screen.dart';

/// Route names
class AppRoutes {
  AppRoutes._();

  static const String splash = '/splash';
  static const String auth = '/auth';
  static const String dashboard = '/dashboard';
  static const String students = '/students';
  static const String seats = '/seats';
  static const String attendance = '/attendance';
  static const String fees = '/fees';
  static const String expenses = '/expenses';
  static const String notices = '/notices';

  static const String addStudent = '/students/add';
  static const String editStudent = '/students/:id/edit';
  static const String studentProfile = '/students/:id';
  static const String importStudents = '/students/import';
  static const String joinRequests = '/students/join-requests';
  static const String notifications = '/notifications';
  static const String sendNotification = '/notifications/send';
  static const String analytics = '/analytics';
  static const String reports = '/reports';
  static const String settings = '/settings';
  static const String profile = '/settings/profile';
  static const String security = '/settings/security';
  static const String librarySettings = '/settings/library';
  static const String staff = '/staff';
  static const String addStaff = '/staff/add';
  static const String librarySetup = '/library-setup';
  static const String libraryBranding = '/library-branding';
  static const String libraryLocation = '/library-location';
  static const String books = '/books';
  static const String seatLayoutEditor = '/seats/layout-editor';
  static const String qrScan = '/attendance/qr-scan';
  static const String help = '/help';
  static const String terms = '/terms';
  static const String isbnScan = '/books/isbn-scan';
  static const String adminPanel = '/admin';
  static const String createTicket = '/support/create';
  static const String myTickets = '/support/tickets';
  static const String ticketChat = '/support/ticket/:id';
  static const String subscription = '/subscription';
  static const String studentPortal = '/student-portal';
  static const String whiteLabel = '/white-label';
}

/// Listenable that fires when auth state changes.
/// Used by GoRouter's refreshListenable so it re-evaluates redirects
/// without recreating the router itself.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen<AsyncValue<AppUser?>>(
      authProvider,
      (previous, next) => notifyListeners(),
    );
  }
}

final _authListenableProvider = Provider<_AuthListenable>((ref) {
  return _AuthListenable(ref);
});

/// GoRouter — created once, auth changes trigger redirect via refreshListenable.
final routerProvider = Provider<GoRouter>((ref) {
  final authListenable = ref.watch(_authListenableProvider);

  return GoRouter(
    navigatorKey: appNavigatorKey,
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    refreshListenable: authListenable,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final location = state.matchedLocation;

      // While auth state is initializing, stay on the splash screen.
      if (authState.isLoading) {
        return location == AppRoutes.splash ? null : AppRoutes.splash;
      }

      // Never auto-leave the splash screen — SplashScreen itself navigates
      // after its minimum display time (5s) has elapsed. This guarantees the
      // loading screen is shown for the intended duration regardless of how
      // fast auth resolves.
      if (location == AppRoutes.splash) return null;

      final isLoggedIn = authState.valueOrNull != null;
      final isOnAuth = location == AppRoutes.auth;

      if (!isLoggedIn && !isOnAuth) return AppRoutes.auth;
      if (isLoggedIn && isOnAuth) return AppRoutes.dashboard;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.auth,
        builder: (context, state) => const AuthScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => BottomNavShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: DashboardScreen()),
          ),
          GoRoute(
            path: AppRoutes.students,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: StudentsListScreen()),
          ),
          GoRoute(
            path: AppRoutes.seats,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SeatManagementScreen()),
          ),
          GoRoute(
            path: AppRoutes.attendance,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: AttendanceScreen()),
          ),
          GoRoute(
            path: AppRoutes.fees,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: FeeManagementScreen()),
          ),
          GoRoute(
            path: AppRoutes.books,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: BookManagementScreen()),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.addStudent,
        builder: (context, state) => const AddStudentScreen(),
      ),
      GoRoute(
        path: AppRoutes.joinRequests,
        builder: (context, state) => const JoinRequestsScreen(),
      ),
      GoRoute(
        path: AppRoutes.editStudent,
        builder: (context, state) =>
            AddStudentScreen(studentId: state.pathParameters['id']),
      ),
      GoRoute(
        path: AppRoutes.importStudents,
        builder: (context, state) => const ImportStudentsScreen(),
      ),
      GoRoute(
        path: AppRoutes.studentProfile,
        builder: (context, state) =>
            StudentProfileScreen(studentId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.sendNotification,
        builder: (context, state) =>
            SendNotificationScreen(initialStudentIds: state.extra as List<String>?),
      ),
      GoRoute(
        path: AppRoutes.analytics,
        builder: (context, state) => const AnalyticsScreen(),
      ),
      GoRoute(
        path: AppRoutes.reports,
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.security,
        builder: (context, state) => const SecurityScreen(),
      ),
      GoRoute(
        path: AppRoutes.librarySettings,
        builder: (context, state) => const LibrarySettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.expenses,
        builder: (context, state) => const ExpenseListScreen(),
      ),
      GoRoute(
        path: AppRoutes.notices,
        builder: (context, state) => const NoticeBoardScreen(),
      ),
      GoRoute(
        path: AppRoutes.staff,
        builder: (context, state) => const StaffListScreen(),
      ),
      GoRoute(
        path: AppRoutes.addStaff,
        builder: (context, state) => const AddStaffScreen(),
      ),
      GoRoute(
        path: AppRoutes.librarySetup,
        builder: (context, state) => const LibrarySetupScreen(),
      ),
      GoRoute(
        path: AppRoutes.libraryBranding,
        builder: (context, state) => const LibraryBrandingScreen(),
      ),
      GoRoute(
        path: AppRoutes.libraryLocation,
        builder: (context, state) => const LibraryLocationScreen(),
      ),
      GoRoute(
        path: AppRoutes.seatLayoutEditor,
        builder: (context, state) => const SeatLayoutEditorScreen(),
      ),
      GoRoute(
        path: AppRoutes.qrScan,
        builder: (context, state) => const QRScanScreen(),
      ),
      GoRoute(
        path: AppRoutes.help,
        builder: (context, state) => const HelpScreen(),
      ),
      GoRoute(
        path: AppRoutes.terms,
        builder: (context, state) => const TermsScreen(),
      ),
      GoRoute(
        path: AppRoutes.isbnScan,
        builder: (context, state) => const ISBNScanScreen(),
      ),
      GoRoute(
        path: AppRoutes.createTicket,
        builder: (context, state) => const CreateTicketScreen(),
      ),
      GoRoute(
        path: AppRoutes.myTickets,
        builder: (context, state) => const MyTicketsScreen(),
      ),
      GoRoute(
        path: AppRoutes.ticketChat,
        builder: (context, state) =>
            TicketChatScreen(ticketId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.adminPanel,
        builder: (context, state) => const AdminPanelScreen(),
      ),
      GoRoute(
        path: AppRoutes.subscription,
        builder: (context, state) => const SubscriptionScreen(),
      ),
      GoRoute(
        path: AppRoutes.studentPortal,
        builder: (context, state) => const StudentPortalScreen(),
      ),
      GoRoute(
        path: AppRoutes.whiteLabel,
        builder: (context, state) => const WhiteLabelScreen(),
      ),
    ],
  );
});
