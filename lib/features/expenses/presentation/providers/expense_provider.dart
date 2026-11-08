import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/expense_model.dart';
import '../../data/repositories/expense_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  final fs = ref.watch(firestoreServiceProvider);
  return ExpenseRepository(fs);
});

final expensesStreamProvider = StreamProvider<List<ExpenseModel>>((ref) {
  final repo = ref.watch(expenseRepositoryProvider);
  return repo.getExpenses();
});

/// Computes total expenses for the current calendar month
final thisMonthExpensesProvider = Provider<double>((ref) {
  final expenses = ref.watch(expensesStreamProvider).valueOrNull ?? [];
  final now = DateTime.now();
  return expenses
      .where((e) => e.date.year == now.year && e.date.month == now.month)
      .fold<double>(0, (sum, e) => sum + e.amount);
});

/// Computes total expenses for today
final todayExpensesProvider = Provider<double>((ref) {
  final expenses = ref.watch(expensesStreamProvider).valueOrNull ?? [];
  final now = DateTime.now();
  return expenses
      .where((e) =>
          e.date.year == now.year &&
          e.date.month == now.month &&
          e.date.day == now.day)
      .fold<double>(0, (sum, e) => sum + e.amount);
});
