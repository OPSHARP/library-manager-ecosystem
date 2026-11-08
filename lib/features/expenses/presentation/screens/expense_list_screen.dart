import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../data/models/expense_model.dart';
import '../providers/expense_provider.dart';

class ExpenseListScreen extends ConsumerStatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  ConsumerState<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends ConsumerState<ExpenseListScreen> {
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Rent',
    'Electricity',
    'WiFi',
    'Maintenance',
    'Cleaning',
    'Salary',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(settingsProvider).currencySymbol;
    final expensesAsync = ref.watch(expensesStreamProvider);
    final thisMonthTotal = ref.watch(thisMonthExpensesProvider);
    final todayTotal = ref.watch(todayExpensesProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 8),
                  Text('Expense Tracker', style: AppTypography.headlineSmall),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 28),
                    color: AppColors.primary,
                    onPressed: () => _showAddExpenseDialog(context),
                  ),
                ],
              ),
            ),

            // Summary Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: GlassContainer(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.trending_down_rounded, size: 16, color: AppColors.error),
                              ),
                              const SizedBox(width: 8),
                              Text('This Month', style: AppTypography.bodySmall.copyWith(color: context.textSecondaryColor)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '$currency${thisMonthTotal.toStringAsFixed(0)}',
                            style: AppTypography.titleLarge.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GlassContainer(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.today_rounded, size: 16, color: AppColors.warning),
                              ),
                              const SizedBox(width: 8),
                              Text('Today', style: AppTypography.bodySmall.copyWith(color: context.textSecondaryColor)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '$currency${todayTotal.toStringAsFixed(0)}',
                            style: AppTypography.titleLarge.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Category Filter Chips
            SizedBox(
              height: 40,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final cat = _categories[idx];
                  final isSelected = _selectedCategory == cat;
                  return ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) setState(() => _selectedCategory = cat);
                    },
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : context.textSecondaryColor,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 12,
                    ),
                    backgroundColor: context.cardBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? AppColors.primary : context.borderColor.withValues(alpha: 0.3),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),

            // List of Expenses
            Expanded(
              child: expensesAsync.when(
                data: (allExpenses) {
                  final filtered = _selectedCategory == 'All'
                      ? allExpenses
                      : allExpenses
                          .where((e) => e.category.toLowerCase() == _selectedCategory.toLowerCase())
                          .toList();

                  if (filtered.isEmpty) {
                    return const EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'No Expenses Recorded',
                      subtitle: 'Track your library expenses (Rent, WiFi, Bills) by tapping + above',
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: filtered.length,
                    itemBuilder: (context, idx) {
                      final item = filtered[idx];
                      return _ExpenseTile(
                        expense: item,
                        currency: currency,
                        onDelete: () => _confirmDelete(context, item),
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddExpenseDialog(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Expense', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  void _showAddExpenseDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String category = 'Rent';
    String paymentMethod = 'Cash';
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Add New Expense', style: AppTypography.titleMedium),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                style: AppTypography.bodyMedium,
                decoration: InputDecoration(
                  labelText: 'Title / Description',
                  hintText: 'e.g. WiFi Bill, Electricity, AC Repair',
                  filled: true,
                  fillColor: context.surfaceColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: AppTypography.bodyMedium,
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        prefixText: '${ref.read(settingsProvider).currencySymbol} ',
                        filled: true,
                        fillColor: context.surfaceColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        filled: true,
                        fillColor: context.surfaceColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      dropdownColor: context.cardBg,
                      items: const [
                        DropdownMenuItem(value: 'Rent', child: Text('Rent')),
                        DropdownMenuItem(value: 'Electricity', child: Text('Electricity')),
                        DropdownMenuItem(value: 'WiFi', child: Text('WiFi')),
                        DropdownMenuItem(value: 'Maintenance', child: Text('Maintenance')),
                        DropdownMenuItem(value: 'Cleaning', child: Text('Cleaning')),
                        DropdownMenuItem(value: 'Salary', child: Text('Salary')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (v) {
                        if (v != null) setSheetState(() => category = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_month_rounded, size: 18),
                      label: Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 30)),
                        );
                        if (picked != null) {
                          setSheetState(() => selectedDate = picked);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: paymentMethod,
                      decoration: InputDecoration(
                        labelText: 'Payment Mode',
                        filled: true,
                        fillColor: context.surfaceColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      dropdownColor: context.cardBg,
                      items: const [
                        DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                        DropdownMenuItem(value: 'Online/UPI', child: Text('Online / UPI')),
                        DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer')),
                        DropdownMenuItem(value: 'Card', child: Text('Card')),
                      ],
                      onChanged: (v) {
                        if (v != null) setSheetState(() => paymentMethod = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                style: AppTypography.bodySmall,
                decoration: InputDecoration(
                  labelText: 'Optional Notes / Bill No.',
                  filled: true,
                  fillColor: context.surfaceColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final title = titleCtrl.text.trim();
                    final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                    if (title.isEmpty || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid title and amount')),
                      );
                      return;
                    }

                    final expense = ExpenseModel(
                      expenseId: '',
                      title: title,
                      amount: amount,
                      category: category,
                      date: selectedDate,
                      notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                      paymentMethod: paymentMethod,
                    );

                    Navigator.pop(ctx);
                    await ref.read(expenseRepositoryProvider).addExpense(expense);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Expense added successfully')),
                      );
                    }
                  },
                  child: const Text('Save Expense', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, ExpenseModel item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardBg,
        title: const Text('Delete Expense?'),
        content: Text('Are you sure you want to delete "${item.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(expenseRepositoryProvider).deleteExpense(item.expenseId);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  final ExpenseModel expense;
  final String currency;
  final VoidCallback onDelete;

  const _ExpenseTile({
    required this.expense,
    required this.currency,
    required this.onDelete,
  });

  IconData _iconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'rent':
        return Icons.home_rounded;
      case 'electricity':
        return Icons.bolt_rounded;
      case 'wifi':
        return Icons.wifi_rounded;
      case 'salary':
        return Icons.badge_rounded;
      case 'maintenance':
        return Icons.build_rounded;
      case 'cleaning':
        return Icons.cleaning_services_rounded;
      default:
        return Icons.receipt_rounded;
    }
  }

  Color _colorForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'rent':
        return AppColors.neonPurple;
      case 'electricity':
        return const Color(0xFFF59E0B);
      case 'wifi':
        return AppColors.neonCyan;
      case 'salary':
        return const Color(0xFF6366F1);
      case 'maintenance':
        return AppColors.error;
      case 'cleaning':
        return AppColors.neonGreen;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForCategory(expense.category);
    final icon = _iconForCategory(expense.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.title,
                  style: AppTypography.titleMedium.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      expense.category,
                      style: AppTypography.bodySmall.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '•  ${DateFormat('dd MMM yyyy').format(expense.date)}',
                      style: AppTypography.bodySmall.copyWith(
                        color: context.textSecondaryColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                if (expense.notes != null && expense.notes!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    expense.notes!,
                    style: AppTypography.bodySmall.copyWith(
                      color: context.textTertiaryColor,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '- $currency${expense.amount.toStringAsFixed(0)}',
                style: AppTypography.labelLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: onDelete,
                child: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
