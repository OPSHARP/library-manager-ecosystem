import 'dart:async';
import 'package:uuid/uuid.dart';
import '../models/expense_model.dart';
import '../../../../core/services/auto_backup_service.dart';
import '../../../../core/services/firestore_service.dart';

class ExpenseRepository {
  final FirestoreService _fs;

  ExpenseRepository(this._fs);

  Stream<List<ExpenseModel>> getExpenses() {
    return _fs.expensesCol
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((d) => ExpenseModel.fromFirestore(d)).toList())
        .handleError((_) => <ExpenseModel>[]);
  }

  Future<void> addExpense(ExpenseModel expense) async {
    final id = expense.expenseId.isEmpty ? const Uuid().v4() : expense.expenseId;
    final model = expense.copyWith(
      expenseId: id,
      createdAt: DateTime.now(),
    );
    await _fs.expensesCol.doc(id).set(model.toFirestore());
    AutoBackupService.instance.triggerBackup(_fs.uid);
  }

  Future<void> updateExpense(ExpenseModel expense) async {
    await _fs.expensesCol.doc(expense.expenseId).update(expense.toFirestore());
    AutoBackupService.instance.triggerBackup(_fs.uid);
  }

  Future<void> deleteExpense(String expenseId) async {
    await _fs.expensesCol.doc(expenseId).delete();
    AutoBackupService.instance.triggerBackup(_fs.uid);
  }
}

