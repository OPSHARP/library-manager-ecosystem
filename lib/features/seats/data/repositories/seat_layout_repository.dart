import '../models/seat_layout_model.dart';
import '../../../../core/services/auto_backup_service.dart';
import '../../../../core/services/firestore_service.dart';

class SeatLayoutRepository {
  final FirestoreService _fs;

  SeatLayoutRepository(this._fs);

  /// Real-time stream of the seat layout document.
  /// Returns null via the stream if no layout exists.
  Stream<SeatLayoutModel?> getLayout() {
    return _fs.seatLayoutsCol.doc('current').snapshots().map((doc) {
      if (!doc.exists) return null;
      return SeatLayoutModel.fromFirestore(doc);
    });
  }

  /// Save (or overwrite) the seat layout.
  Future<void> saveLayout(SeatLayoutModel layout) async {
    await _fs.seatLayoutsCol.doc('current').set(layout.toFirestore());
    AutoBackupService.instance.triggerBackup(_fs.uid);
  }

  /// Delete the seat layout.
  Future<void> deleteLayout() async {
    await _fs.seatLayoutsCol.doc('current').delete();
    AutoBackupService.instance.triggerBackup(_fs.uid);
  }
}
