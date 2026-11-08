import 'package:uuid/uuid.dart';
import '../models/staff_model.dart';
import '../../../../core/services/auto_backup_service.dart';
import '../../../../core/services/firestore_service.dart';

class StaffRepository {
  final FirestoreService _fs;
  StaffRepository(this._fs);

  Stream<List<StaffModel>> getStaff() {
    return _fs.staffCol
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => StaffModel.fromFirestore(doc)).toList());
  }

  Future<String> addStaff(StaffModel staff) async {
    final id = staff.staffId.isEmpty ? const Uuid().v4() : staff.staffId;
    final newStaff = staff.copyWith(createdAt: DateTime.now());
    await _fs.staffCol.doc(id).set({
      ...newStaff.toFirestore(),
      'staffId': id,
    });
    AutoBackupService.instance.triggerBackup(_fs.uid);
    return id;
  }

  Future<void> updateStaff(StaffModel staff) async {
    await _fs.staffCol.doc(staff.staffId).update(staff.toFirestore());
    AutoBackupService.instance.triggerBackup(_fs.uid);
  }

  Future<void> toggleStaffStatus(String staffId, bool isActive) async {
    await _fs.staffCol.doc(staffId).update({'isActive': isActive});
    AutoBackupService.instance.triggerBackup(_fs.uid);
  }

  Future<void> deleteStaff(String staffId) async {
    await _fs.staffCol.doc(staffId).delete();
    AutoBackupService.instance.triggerBackup(_fs.uid);
  }
}
