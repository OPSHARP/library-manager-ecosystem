import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/seat_model.dart';
import '../../../../core/services/auto_backup_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../subscription/data/services/plan_guard.dart';

class SeatRepository {
  final FirestoreService _fs;

  SeatRepository(this._fs);

  // ─── Streams ───

  /// Real-time stream of all seats ordered by seatNumber.
  /// Optional [category] filter applied client-side.
  Stream<List<SeatModel>> getSeats({String? category}) {
    return _fs.seatsCol.orderBy('seatNumber').snapshots().map((snapshot) {
      var seats = snapshot.docs.map((d) => SeatModel.fromFirestore(d)).toList();
      if (category != null && category != 'All') {
        if (category == 'Reserved') {
          seats = seats.where((s) => s.status == 'reserved').toList();
        } else {
          seats =
              seats.where((s) => s.category.toLowerCase() == category.toLowerCase()).toList();
        }
      }
      return seats;
    }).handleError((error) {
      return <SeatModel>[];
    });
  }

  // ─── CRUD ───

  Future<SeatModel> getSeat(String seatId) async {
    final doc = await _fs.seatsCol.doc(seatId).get();
    if (!doc.exists) throw Exception('Seat not found');
    return SeatModel.fromFirestore(doc);
  }

  Future<String> addSeat(SeatModel seat) async {
    await PlanGuard(_fs).guardSeatAdd();
    final id = seat.seatId.isEmpty ? const Uuid().v4() : seat.seatId;
    final newSeat = seat.copyWith(seatId: id, createdAt: DateTime.now());
    await _fs.seatsCol.doc(id).set(newSeat.toFirestore());
    unawaited(syncSeatAvailability());
    AutoBackupService.instance.triggerBackup(_fs.uid);
    return id;
  }

  Future<void> updateSeat(SeatModel seat) async {
    await _fs.seatsCol.doc(seat.seatId).update(seat.toFirestore());
    unawaited(syncSeatAvailability());
    AutoBackupService.instance.triggerBackup(_fs.uid);
  }

  Future<void> deleteSeat(String seatId) async {
    await _fs.seatsCol.doc(seatId).delete();
    unawaited(syncSeatAvailability());
    AutoBackupService.instance.triggerBackup(_fs.uid);
  }

  // ─── Seat operations (transactional) ───

  Future<void> allocateSeat(
    String seatId,
    String studentId,
    String studentName,
  ) async {
    await _fs.firestore.runTransaction((transaction) async {
      final docRef = _fs.seatsCol.doc(seatId);
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) throw Exception('Seat not found');
      final seat = SeatModel.fromFirestore(snapshot);
      if (seat.status != 'available') throw Exception('Seat is not available');
      final updated = seat.copyWith(
        status: 'occupied',
        assignedStudentId: studentId,
        assignedStudentName: studentName,
        renewalDate: DateTime.now().add(const Duration(days: 30)),
      );
      transaction.update(docRef, updated.toFirestore());
    });
    unawaited(syncSeatAvailability());
    AutoBackupService.instance.triggerBackup(_fs.uid);
  }

  Future<void> releaseSeat(String seatId) async {
    await _fs.firestore.runTransaction((transaction) async {
      final docRef = _fs.seatsCol.doc(seatId);
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) throw Exception('Seat not found');
      final seat = SeatModel.fromFirestore(snapshot);
      final updated = seat.copyWith(
        status: 'available',
        assignedStudentId: null,
        assignedStudentName: null,
        renewalDate: null,
        shifts: null,
      );
      transaction.update(docRef, updated.toFirestore());
    });
    unawaited(syncSeatAvailability());
    AutoBackupService.instance.triggerBackup(_fs.uid);
  }

  Future<void> allocateShiftSeat({
    required String seatId,
    required String shift,
    required String studentId,
    required String studentName,
    DateTime? renewalDate,
  }) async {
    await _fs.firestore.runTransaction((transaction) async {
      final docRef = _fs.seatsCol.doc(seatId);
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) throw Exception('Seat not found');
      final seat = SeatModel.fromFirestore(snapshot);
      if (!seat.isShiftAvailable(shift)) {
        throw Exception('Seat is not available for $shift shift');
      }

      final updatedShifts = Map<String, ShiftAssignment>.from(seat.shifts ?? {});
      updatedShifts[shift] = ShiftAssignment(
        studentId: studentId,
        studentName: studentName,
        renewalDate: renewalDate ?? DateTime.now().add(const Duration(days: 30)),
      );

      final updated = seat.copyWith(
        status: (updatedShifts.containsKey('full_day') || updatedShifts.length >= 3)
            ? 'occupied'
            : seat.status,
        shifts: updatedShifts,
      );
      transaction.update(docRef, updated.toFirestore());
    });
    unawaited(syncSeatAvailability());
    AutoBackupService.instance.triggerBackup(_fs.uid);
  }

  Future<void> releaseShiftSeat({
    required String seatId,
    required String shift,
  }) async {
    await _fs.firestore.runTransaction((transaction) async {
      final docRef = _fs.seatsCol.doc(seatId);
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) throw Exception('Seat not found');
      final seat = SeatModel.fromFirestore(snapshot);
      final updatedShifts = Map<String, ShiftAssignment>.from(seat.shifts ?? {});
      updatedShifts.remove(shift);

      final updated = seat.copyWith(
        status: updatedShifts.isEmpty ? 'available' : seat.status,
        shifts: updatedShifts.isEmpty ? null : updatedShifts,
      );
      transaction.update(docRef, updated.toFirestore());
    });
    unawaited(syncSeatAvailability());
    AutoBackupService.instance.triggerBackup(_fs.uid);
  }

  Future<void> reserveSeat(
    String seatId,
    String studentId,
    String studentName,
    DateTime reservedFrom,
    DateTime reservedUntil,
  ) async {
    await _fs.firestore.runTransaction((transaction) async {
      final docRef = _fs.seatsCol.doc(seatId);
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) throw Exception('Seat not found');
      final seat = SeatModel.fromFirestore(snapshot);
      if (seat.status != 'available') throw Exception('Seat is not available');
      final updated = seat.copyWith(
        status: 'reserved',
        reservation: SeatReservation(
          reservedBy: studentId,
          reservedByName: studentName,
          reservedFrom: reservedFrom,
          reservedUntil: reservedUntil,
        ),
      );
      transaction.update(docRef, updated.toFirestore());
    });
    unawaited(syncSeatAvailability());
  }

  Future<void> cancelReservation(String seatId) async {
    await _fs.firestore.runTransaction((transaction) async {
      final docRef = _fs.seatsCol.doc(seatId);
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) throw Exception('Seat not found');
      final seat = SeatModel.fromFirestore(snapshot);
      final updated = seat.copyWith(
        status: 'available',
        reservation: null,
      );
      transaction.update(docRef, updated.toFirestore());
    });
    unawaited(syncSeatAvailability());
  }

  // ─── Counts (aggregation queries) ───

  Future<int> getSeatCount() async {
    final agg = await _fs.seatsCol.count().get();
    return agg.count ?? 0;
  }

  Future<int> getOccupiedSeatCount() async {
    final agg =
        await _fs.seatsCol.where('status', isEqualTo: 'occupied').count().get();
    return agg.count ?? 0;
  }

  Future<int> getAvailableSeatCount() async {
    final agg = await _fs.seatsCol
        .where('status', isEqualTo: 'available')
        .count()
        .get();
    return agg.count ?? 0;
  }

  /// Recomputes the PUBLIC "available seats" counter on the library document
  /// (read by students in the portal). Before any seat layout exists, the
  /// available count equals the configured seat capacity.
  Future<void> syncSeatAvailability() async {
    try {
      final libRef = _fs.librariesCol.doc('lib_${_fs.uid}');
      final libDoc = await libRef.get();
      final capacity = (libDoc.data()?['seatCapacity'] as num?)?.toInt() ?? 0;
      final total = await getSeatCount();
      final available = total > 0 ? await getAvailableSeatCount() : capacity;
      await libRef.set({
        'availableSeats': available,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      AutoBackupService.instance.triggerBackup(_fs.uid);
    } catch (_) {
      // Non-critical — the counter simply stays at its last good value.
    }
  }
}
