import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/attendance/data/models/attendance_model.dart';
import '../../features/attendance/data/repositories/attendance_repository.dart';

class OfflineAttendanceService {
  OfflineAttendanceService._internal();
  static final OfflineAttendanceService instance = OfflineAttendanceService._internal();

  static const String _kQueueKey = 'offline_attendance_queue_v1';
  final ValueNotifier<int> pendingCountNotifier = ValueNotifier<int>(0);

  AttendanceRepository? _repository;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isSyncing = false;
  bool _initialized = false;

  /// Initializes the offline service, restores pending queue count, and sets
  /// up automatic background syncing when connectivity is restored.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_kQueueKey) ?? [];
      pendingCountNotifier.value = list.length;

      _connectivitySub = Connectivity().onConnectivityChanged.listen((results) async {
        final connected = results.any((r) => r != ConnectivityResult.none);
        if (connected && pendingCountNotifier.value > 0 && !_isSyncing) {
          debugPrint('🌐 Network reconnected: auto-flushing offline attendance queue...');
          await syncQueue();
        }
      });
    } catch (e) {
      debugPrint('Error initializing OfflineAttendanceService: $e');
    }
  }

  /// Registers an active AttendanceRepository instance for auto-sync.
  void registerRepository(AttendanceRepository repo) {
    _repository = repo;
    // If pending items exist and we are online, trigger immediate sync
    if (pendingCountNotifier.value > 0) {
      isOnline().then((online) {
        if (online && !_isSyncing) {
          syncQueue(repo);
        }
      });
    }
  }

  /// Checks whether device currently has active network connectivity.
  Future<bool> isOnline() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return true;
    }
  }

  /// Saves an attendance mark record to the local persistent queue.
  Future<void> enqueue({
    required String dateKey,
    required AttendanceRecord record,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_kQueueKey) ?? [];

      final item = {
        'action': 'mark',
        'dateKey': dateKey,
        'record': record.toJson(),
        'retries': 0,
        'enqueuedAt': DateTime.now().toIso8601String(),
      };

      list.add(jsonEncode(item));
      await prefs.setStringList(_kQueueKey, list);
      pendingCountNotifier.value = list.length;
      debugPrint('📥 Enqueued offline attendance for ${record.studentName} (total queued: ${list.length})');
    } catch (e) {
      debugPrint('Error enqueuing offline attendance: $e');
    }
  }

  /// Saves an attendance check-out operation to the local persistent queue.
  Future<void> enqueueCheckOut({
    required String dateKey,
    required String studentId,
    DateTime? checkOutTime,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_kQueueKey) ?? [];

      final item = {
        'action': 'checkOut',
        'dateKey': dateKey,
        'studentId': studentId,
        'checkOutTime': (checkOutTime ?? DateTime.now()).toIso8601String(),
        'retries': 0,
        'enqueuedAt': DateTime.now().toIso8601String(),
      };

      list.add(jsonEncode(item));
      await prefs.setStringList(_kQueueKey, list);
      pendingCountNotifier.value = list.length;
      debugPrint('📥 Enqueued offline check-out for student $studentId on $dateKey');
    } catch (e) {
      debugPrint('Error enqueuing offline check-out: $e');
    }
  }

  /// Synchronizes all queued attendance records to Firestore.
  /// Drops poisoned items after 3 retries to prevent queue blocking.
  Future<int> syncQueue([AttendanceRepository? repo]) async {
    final activeRepo = repo ?? _repository;
    if (activeRepo == null || _isSyncing) return 0;

    _isSyncing = true;
    int syncedCount = 0;

    try {
      final online = await isOnline();
      if (!online) {
        _isSyncing = false;
        return 0;
      }

      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_kQueueKey) ?? [];
      if (list.isEmpty) {
        pendingCountNotifier.value = 0;
        _isSyncing = false;
        return 0;
      }

      final remainingList = <String>[];

      for (final rawJson in list) {
        Map<String, dynamic>? map;
        try {
          map = jsonDecode(rawJson) as Map<String, dynamic>;
          final action = map['action'] ?? 'mark';
          final dateKey = map['dateKey'] as String;

          if (action == 'checkOut') {
            final studentId = map['studentId'] as String;
            final checkOutTime = DateTime.tryParse(map['checkOutTime'] ?? '');
            await activeRepo.checkOutDirect(
              dateKey: dateKey,
              studentId: studentId,
              checkOutTime: checkOutTime,
            );
            syncedCount++;
            debugPrint('✅ Synced offline check-out for student $studentId on $dateKey');
          } else {
            final recordMap = Map<String, dynamic>.from(map['record'] as Map);
            final record = AttendanceRecord.fromJson(recordMap);
            await activeRepo.markAttendanceDirect(
              dateKey: dateKey,
              record: record,
            );
            syncedCount++;
            debugPrint('✅ Synced offline attendance for ${record.studentName} on $dateKey');
          }
        } catch (e) {
          if (map != null) {
            final retries = (map['retries'] as int? ?? 0) + 1;
            if (retries < 3) {
              map['retries'] = retries;
              remainingList.add(jsonEncode(map));
              debugPrint('⚠️ Failed to sync queued item (attempt $retries/3): $e');
            } else {
              debugPrint('❌ Discarded poison-pill queued attendance item after 3 attempts: $e');
            }
          }
        }
      }

      await prefs.setStringList(_kQueueKey, remainingList);
      pendingCountNotifier.value = remainingList.length;
    } catch (e) {
      debugPrint('Error during attendance queue sync: $e');
    } finally {
      _isSyncing = false;
    }

    return syncedCount;
  }

  /// Cleans up any resources.
  void dispose() {
    _connectivitySub?.cancel();
  }
}
