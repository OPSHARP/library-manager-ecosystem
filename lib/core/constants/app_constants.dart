/// App-wide constants for Library Manager and Owner
class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'Library Manager and Owner';
  static const String appVersion = '2.0.0';
  static const String appTagline = 'Smart Library Management';

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxSearchResults = 50;

  // Free-plan limits (upgrade to Pro for unlimited access)
  static const int maxStudents = 10; // free plan limit
  static const int maxSeats = 10; // free plan limit
  static const int maxAttendanceRecords = 10; // free plan limit
  static const int maxFees = 10; // free plan limit

  // Upgrade prompt
  static const String upgradeToastMessage =
      'Please Upgrade Your Plan if Use Unlimited Features Access';

  // Image
  static const int maxImageSizeBytes = 512000; // 500KB
  static const double imageQuality = 0.7;
  static const int thumbnailSize = 200;

  // Timeouts
  static const int networkTimeoutSeconds = 30;
  static const int cacheExpiryMinutes = 30;

  // Attendance
  static const String lateThresholdTime = '10:00'; // After 10 AM = late

  // Admin
  static const String adminEmail = 'tarunvip934@gmail.com';

  // Date Formats
  static const String dateFormat = 'dd MMM yyyy';
  static const String timeFormat = 'hh:mm a';
  static const String dateTimeFormat = 'dd MMM yyyy, hh:mm a';
  static const String monthYearFormat = 'MMMM yyyy';
  static const String firestoreDateKey = 'yyyy-MM-dd';

  // ── Password Reset Deep Link ─────────────────────────────────────────
  // The continue-URL used in password-reset emails. This uses the project's
  // own Firebase domain (no custom domain required) so the link can open the
  // app directly via Android App Links.
  //
  // How it works WITHOUT owning a domain:
  //   * Firebase automatically hosts `assetlinks.json` on
  //     mynotebookpro-edec0.firebaseapp.com / .web.app for apps registered
  //     in the project, so the email link opens the app instead of Chrome.
  //   * For that App-Link verification to pass you must add the signing
  //     certificate's SHA-256 fingerprint in Firebase Console:
  //       Project settings → Your apps → (Android app) →
  //       "SHA certificate fingerprints" → add:
  //       Release: ea14142e23f428bc0c5b5b9b089d502c6eac686e25bd6d569dadd36f056a0b72
  //       Debug:    (run `keytool -list -v -keystore ~/.android/debug.keystore`)
  //   * The Firebase project ID will still appear in the URL hostname
  //     (`mynotebookpro-edec0.firebaseapp.com`). Hiding it completely
  //     requires a custom domain (Firebase limitation); with App Links
  //     working, users tap the link and land in the app, so they never see
  //     the browser URL anyway.
  static const String passwordResetDeepLink =
      'https://mynotebookpro-edec0.firebaseapp.com/';
}
