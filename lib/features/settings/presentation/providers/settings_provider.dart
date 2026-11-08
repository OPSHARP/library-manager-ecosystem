import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Returns the current FirestoreService, or null if not authenticated.
/// SettingsProvider uses this to avoid querying Firestore with a pending uid.
final _safeFirestoreProvider = Provider<FirestoreService?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return FirestoreService(uid: user.uid);
});

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) {
    final fs = ref.watch(_safeFirestoreProvider);
    final notifier = SettingsNotifier(fs);
    ref.onDispose(() => notifier.dispose());
    return notifier;
  },
);

class SettingsState {
  final String language;
  final bool notificationsEnabled;
  final bool feeRemindersEnabled;
  final bool attendanceAlertsEnabled;
  final bool promotionalNotificationsEnabled;
  final String currencySymbol;
  final String currencyCode;
  final String currencyLocale;
  final bool isLoading;

  const SettingsState({
    this.language = 'English',
    this.notificationsEnabled = true,
    this.feeRemindersEnabled = true,
    this.attendanceAlertsEnabled = true,
    this.promotionalNotificationsEnabled = true,
    this.currencySymbol = '\$',
    this.currencyCode = 'USD',
    this.currencyLocale = 'en_US',
    this.isLoading = true,
  });

  SettingsState copyWith({
    String? language,
    bool? notificationsEnabled,
    bool? feeRemindersEnabled,
    bool? attendanceAlertsEnabled,
    bool? promotionalNotificationsEnabled,
    String? currencySymbol,
    String? currencyCode,
    String? currencyLocale,
    bool? isLoading,
  }) {
    return SettingsState(
      language: language ?? this.language,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      feeRemindersEnabled: feeRemindersEnabled ?? this.feeRemindersEnabled,
      attendanceAlertsEnabled:
          attendanceAlertsEnabled ?? this.attendanceAlertsEnabled,
      promotionalNotificationsEnabled:
          promotionalNotificationsEnabled ??
          this.promotionalNotificationsEnabled,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      currencyCode: currencyCode ?? this.currencyCode,
      currencyLocale: currencyLocale ?? this.currencyLocale,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final FirestoreService? _fs;
  StreamSubscription? _firestoreSubscription;

  SettingsNotifier(this._fs) : super(const SettingsState()) {
    _loadFromPrefs();
    if (_fs != null) _watchFirestore();
  }

  /// Fast local load from SharedPreferences before Firestore responds.
  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = state.copyWith(
        language: prefs.getString('language'),
        notificationsEnabled: prefs.getBool('notificationsEnabled'),
        feeRemindersEnabled: prefs.getBool('feeRemindersEnabled'),
        attendanceAlertsEnabled: prefs.getBool('attendanceAlertsEnabled'),
        promotionalNotificationsEnabled: prefs.getBool('promotionalNotificationsEnabled'),
        currencySymbol: prefs.getString('currencySymbol'),
        currencyCode: prefs.getString('currencyCode'),
        currencyLocale: prefs.getString('currencyLocale'),
        isLoading: false,
      );
      unawaited(_syncCurrencyToLibrary());
    } catch (e) {
      state = state.copyWith(isLoading: false);
      unawaited(_syncCurrencyToLibrary());
    }
  }

  /// Keeps the PUBLIC library document's `currency` in sync with the owner's
  /// chosen symbol. Students read the library doc (they cannot read settings),
  /// so if it goes stale (e.g. an old build changed currency before this sync
  /// existed) the portal would keep showing the previous symbol. This runs on
  /// every settings load + change so existing libraries self-heal.
  Future<void> _syncCurrencyToLibrary() async {
    if (_fs == null) return;
    try {
      final symbol = state.currencySymbol;
      await _fs.librariesCol.doc('lib_${_fs.uid}').set({
        'currency': symbol.isEmpty ? '\$' : symbol,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Best-effort — settings remain the source of truth for the owner.
    }
  }

  /// Listen to Firestore settings doc for real-time updates.
  void _watchFirestore() {
    _firestoreSubscription?.cancel();
    _firestoreSubscription = _fs!.settingsDoc.snapshots().listen((doc) {
      if (!doc.exists) return;
      final data = doc.data()!;
      state = state.copyWith(
        language: data['language'] as String?,
        notificationsEnabled: data['notificationsEnabled'] as bool?,
        feeRemindersEnabled: data['feeRemindersEnabled'] as bool?,
        attendanceAlertsEnabled: data['attendanceAlertsEnabled'] as bool?,
        promotionalNotificationsEnabled: data['promotionalNotificationsEnabled'] as bool?,
        currencySymbol: data['currencySymbol'] as String?,
        currencyCode: data['currencyCode'] as String?,
        currencyLocale: data['currencyLocale'] as String?,
        isLoading: false,
      );
      // Update SharedPreferences cache
      _syncPrefs(data);
      unawaited(_syncCurrencyToLibrary());
    }, onError: (_) {
    });
  }

  Future<void> _syncPrefs(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (data.containsKey('language') && data['language'] is String) {
        await prefs.setString('language', data['language'] as String);
      }
      if (data.containsKey('currencySymbol') && data['currencySymbol'] is String) {
        await prefs.setString('currencySymbol', data['currencySymbol'] as String);
      }
      if (data.containsKey('currencyCode') && data['currencyCode'] is String) {
        await prefs.setString('currencyCode', data['currencyCode'] as String);
      }
      if (data.containsKey('currencyLocale') && data['currencyLocale'] is String) {
        await prefs.setString('currencyLocale', data['currencyLocale'] as String);
      }
    } catch (_) {
    }
  }

  @override
  void dispose() {
    _firestoreSubscription?.cancel();
    super.dispose();
  }

  Future<void> _persist(String key, dynamic value) async {
    try {
      if (_fs != null) {
        // Include createdAt on the first write so the Firestore rules
        // (which require `createdAt is timestamp` on creates) don't deny it.
        await _fs.settingsDoc.set(
          {
            key: value,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
      final prefs = await SharedPreferences.getInstance();
      if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      }
    } catch (_) {
      // Persist failures are non-critical; the in-memory state stays valid.
    }
  }

  Future<void> setLanguage(String language) async {
    final prev = state;
    state = state.copyWith(language: language);
    try {
      await _persist('language', language);
    } catch (_) {
      state = prev;
    }
  }

  Future<void> toggleNotifications() async {
    final prev = state;
    state = state.copyWith(notificationsEnabled: !state.notificationsEnabled);
    try {
      await _persist('notificationsEnabled', state.notificationsEnabled);
    } catch (_) {
      state = prev;
    }
  }

  Future<void> toggleFeeReminders() async {
    final prev = state;
    state = state.copyWith(feeRemindersEnabled: !state.feeRemindersEnabled);
    try {
      await _persist('feeRemindersEnabled', state.feeRemindersEnabled);
    } catch (_) {
      state = prev;
    }
  }

  Future<void> toggleAttendanceAlerts() async {
    final prev = state;
    state = state.copyWith(attendanceAlertsEnabled: !state.attendanceAlertsEnabled);
    try {
      await _persist('attendanceAlertsEnabled', state.attendanceAlertsEnabled);
    } catch (_) {
      state = prev;
    }
  }

  Future<void> togglePromotionalNotifications() async {
    final prev = state;
    state = state.copyWith(promotionalNotificationsEnabled: !state.promotionalNotificationsEnabled);
    try {
      await _persist('promotionalNotificationsEnabled', state.promotionalNotificationsEnabled);
    } catch (_) {
      state = prev;
    }
  }

  Future<void> setCurrency(String symbol, String code, String locale) async {
    final prev = state;
    state = state.copyWith(currencySymbol: symbol, currencyCode: code, currencyLocale: locale);
    try {
      await _persist('currencySymbol', symbol);
      await _persist('currencyCode', code);
      await _persist('currencyLocale', locale);
      // Push the currency to the public library doc so the Students Portal
      // shows the SAME symbol on fees — and updates automatically whenever
      // the owner changes it (students read the library doc live).
      await _syncCurrencyToLibrary();
    } catch (_) {
      state = prev;
    }
  }

  Future<void> reloadFromPrefs() async {
    await _loadFromPrefs();
  }
}
