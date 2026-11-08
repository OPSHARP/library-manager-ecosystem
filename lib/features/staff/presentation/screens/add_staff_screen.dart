import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/neon_button.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/utils/extensions.dart';
import '../../data/models/staff_model.dart';
import '../../presentation/providers/staff_provider.dart';

/// Add Staff Screen - Invite staff with role selection
class AddStaffScreen extends ConsumerStatefulWidget {
  const AddStaffScreen({super.key});

  @override
  ConsumerState<AddStaffScreen> createState() => _AddStaffScreenState();
}

class _AddStaffScreenState extends ConsumerState<AddStaffScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedRole = 'reception_manager';
  String _selectedShift = 'full_day';
  bool _isLoading = false;

  final _roles = [
    {'value': 'reception_manager', 'label': 'Reception Manager', 'icon': Icons.desk_rounded, 'color': AppColors.primary},
    {'value': 'attendance_manager', 'label': 'Attendance Manager', 'icon': Icons.fact_check_rounded, 'color': AppColors.accent},
    {'value': 'fee_collection', 'label': 'Fee Collection', 'icon': Icons.receipt_long_rounded, 'color': AppColors.neonPink},
  ];

  final _shifts = [
    {'value': 'morning', 'label': 'Morning (6AM-2PM)', 'icon': Icons.wb_sunny_rounded, 'color': const Color(0xFFF59E0B)},
    {'value': 'afternoon', 'label': 'Afternoon (2PM-10PM)', 'icon': Icons.wb_cloudy_rounded, 'color': const Color(0xFF3B82F6)},
    {'value': 'night', 'label': 'Night (10PM-6AM)', 'icon': Icons.nights_stay_rounded, 'color': const Color(0xFF8B5CF6)},
    {'value': 'full_day', 'label': 'Full Day', 'icon': Icons.schedule_rounded, 'color': const Color(0xFF10B981)},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _inviteStaff() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final repo = ref.read(staffRepositoryProvider);
    final staff = StaffModel(
      staffId: const Uuid().v4(),
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      role: _selectedRole,
      shift: _selectedShift,
      isActive: true,
      createdAt: DateTime.now(),
    );

    await repo.addStaff(staff);
    if (mounted) {
      setState(() => _isLoading = false);
      context.showSuccess('Staff added successfully');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: context.scaffoldBg,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop()),
                    const SizedBox(width: 8),
                    Text('Add Staff', style: AppTypography.headlineSmall),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),

                      // Staff info
                      Text('Staff Information', style: AppTypography.titleMedium),
                      const SizedBox(height: 14),
                      Form(
                        key: _formKey,
                        child: GlassContainer(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Full Name', style: AppTypography.labelLarge),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _nameController,
                              textCapitalization: TextCapitalization.words,
                              validator: Validators.name,
                              decoration: const InputDecoration(
                                hintText: 'Staff member name',
                                prefixIcon: Icon(Icons.person_rounded),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text('Email', style: AppTypography.labelLarge),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              validator: Validators.email,
                              decoration: const InputDecoration(
                                hintText: 'staff@example.com',
                                prefixIcon: Icon(Icons.email_rounded),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text('Phone', style: AppTypography.labelLarge),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              validator: Validators.phone,
                              decoration: const InputDecoration(
                                hintText: '+91 9876543210',
                                prefixIcon: Icon(Icons.phone_rounded),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ),
                      const SizedBox(height: 24),

                      // Role selection
                      Text('Assign Role', style: AppTypography.titleMedium),
                      const SizedBox(height: 14),
                      ..._roles.map((role) {
                        final isSelected = _selectedRole == role['value'];
                        final color = role['color'] as Color;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedRole = role['value'] as String),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected ? color.withValues(alpha: 0.1) : context.cardBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? color : context.borderColor.withValues(alpha: 0.3),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42, height: 42,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(role['icon'] as IconData, size: 22, color: color),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(role['label'] as String, style: AppTypography.labelLarge),
                                      Text(
                                        _getRoleDescription(role['value'] as String),
                                        style: AppTypography.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Icon(Icons.check_circle_rounded, color: color, size: 24),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 24),

                      // Shift selection
                      Text('Assign Shift', style: AppTypography.titleMedium),
                      const SizedBox(height: 14),
                      ..._shifts.map((shift) {
                        final isSelected = _selectedShift == shift['value'];
                        final color = shift['color'] as Color;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedShift = shift['value'] as String),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected ? color.withValues(alpha: 0.1) : context.cardBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? color : context.borderColor.withValues(alpha: 0.3),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42, height: 42,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(shift['icon'] as IconData, size: 22, color: color),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(shift['label'] as String, style: AppTypography.labelLarge),
                                ),
                                if (isSelected)
                                  Icon(Icons.check_circle_rounded, color: color, size: 24),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 32),

                      NeonButton(
                        text: 'Send Invitation',
                        onPressed: _inviteStaff,
                        isLoading: _isLoading,
                        width: double.infinity,
                        icon: Icons.person_add_rounded,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getRoleDescription(String role) {
    switch (role) {
      case 'reception_manager':
        return 'Manage students, seats, and general operations';
      case 'attendance_manager':
        return 'Mark and manage daily attendance';
      case 'fee_collection':
        return 'Record and track fee payments';
      default:
        return '';
    }
  }
}
