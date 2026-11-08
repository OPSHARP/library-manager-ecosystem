import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../presentation/providers/student_provider.dart';
import '../../data/models/student_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/neon_button.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/constants/currency_constants.dart';
import '../../../../core/widgets/plan_upgrade_prompt.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../../subscription/data/services/plan_guard.dart';

/// Add/Edit Student Screen
/// Multi-section form for adding or editing a student
class AddStudentScreen extends ConsumerStatefulWidget {
  final String? studentId;
  const AddStudentScreen({super.key, this.studentId});

  bool get isEditing => studentId != null;

  @override
  ConsumerState<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends ConsumerState<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _parentPhoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _feeAmountController;
  late final TextEditingController _idProofController;
  late final TextEditingController _uniqueIdController;
  late String _selectedSeatCategory;
  late String _selectedFeePlan;
  bool _isLoading = false;
  File? _photoFile;
  StudentModel? _student;

  @override
  void initState() {
    super.initState();
    _initFromStudent();
  }

  void _initFromStudent() {
    if (!widget.isEditing) {
      // Auto-fetch the dial code from the currently selected currency.
      final dialCode =
          dialCodeForCurrency(ref.read(settingsProvider).currencyCode);
      _nameController = TextEditingController();
      _phoneController = TextEditingController(text: '$dialCode ');
      _parentPhoneController = TextEditingController(text: '$dialCode ');
      _addressController = TextEditingController();
      _feeAmountController = TextEditingController();
      _idProofController = TextEditingController();
      _uniqueIdController = TextEditingController();
      _selectedSeatCategory = 'Normal';
      _selectedFeePlan = 'Monthly';
      _refreshDialCodeFromPrefs();
      return;
    }

    final students = ref.read(studentsProvider).valueOrNull ?? [];
    _student = students.where((s) => s.studentId == widget.studentId).firstOrNull;
    final s = _student;
    _nameController = TextEditingController(text: s?.name ?? '');
    _phoneController = TextEditingController(text: s?.phone ?? '');
    _parentPhoneController = TextEditingController(text: s?.parentPhone ?? '');
    _addressController = TextEditingController(text: s?.address ?? '');
    _feeAmountController = TextEditingController(text: s != null ? s.feeAmount.toStringAsFixed(0) : '');
    _idProofController = TextEditingController(text: s?.idProofUrl ?? '');
    _uniqueIdController = TextEditingController(text: s?.uniqueId ?? '');
    _selectedSeatCategory = 'Normal';
    _selectedFeePlan = s?.feePlan ?? 'Monthly';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _parentPhoneController.dispose();
    _addressController.dispose();
    _feeAmountController.dispose();
    _idProofController.dispose();
    _uniqueIdController.dispose();
    super.dispose();
  }

  /// Re-reads the saved currency from SharedPreferences (the settings
  /// provider may still be loading when initState runs) and updates the
  /// dial-code prefix in the phone fields if the user hasn't typed yet.
  Future<void> _refreshDialCodeFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final code = prefs.getString('currencyCode') ?? 'USD';
    final dialCode = dialCodeForCurrency(code);
    if (_phoneController.text.trim().isEmpty || _phoneController.text.trim() == '+') {
      _phoneController.text = '$dialCode ';
    }
    if (_parentPhoneController.text.trim().isEmpty ||
        _parentPhoneController.text.trim() == '+') {
      _parentPhoneController.text = '$dialCode ';
    }
  }

  Future<void> _onSave() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final repo = ref.read(studentRepositoryProvider);

        if (widget.isEditing) {
          final updated = _student!.copyWith(
            name: _nameController.text.trim(),
            uniqueId: _uniqueIdController.text.trim().toUpperCase(),
            phone: _phoneController.text.trim(),
            parentPhone: _parentPhoneController.text.trim().isNotEmpty ? _parentPhoneController.text.trim() : null,
            address: _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : null,
            idProofUrl: _idProofController.text.trim().isNotEmpty ? _idProofController.text.trim() : null,
            feePlan: _selectedFeePlan,
            feeAmount: double.tryParse(_feeAmountController.text) ?? 0,
          );
          await repo.updateStudent(updated);
        } else {
          final student = StudentModel(
            studentId: const Uuid().v4(),
            uniqueId: _uniqueIdController.text.trim().toUpperCase(),
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            parentPhone: _parentPhoneController.text.trim().isNotEmpty ? _parentPhoneController.text.trim() : null,
            address: _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : null,
            idProofUrl: _idProofController.text.trim().isNotEmpty ? _idProofController.text.trim() : null,
            feePlan: _selectedFeePlan,
            feeAmount: double.tryParse(_feeAmountController.text) ?? 0,
            isActive: true,
            createdAt: DateTime.now(),
          );
          final newId = await repo.addStudent(student);
          ref.read(activityRepositoryProvider).logActivity(
            type: 'student_added',
            description: 'Added student: ${student.name}',
            relatedId: newId,
          );
        }

        if (mounted) {
          setState(() => _isLoading = false);
          context.showSuccess(widget.isEditing ? 'Student updated successfully' : 'Student added successfully');
          context.pop();
        }
      } on PlanLimitExceededException {
        if (mounted) {
          setState(() => _isLoading = false);
          showUpgradePlanDialog(context);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          context.showError('Failed to save student. Please try again.');
        }
      }
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
              // App bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: 8),
                    Text(widget.isEditing ? 'Edit Student' : 'Add Student', style: AppTypography.headlineSmall),
                  ],
                ),
              ),

              // Form
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Photo upload
                        Center(
                          child: GestureDetector(
                            onTap: () async {
                              final picker = ImagePicker();
                              final image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 80);
                              if (image != null && mounted) setState(() => _photoFile = File(image.path));
                            },
                            child: Container(
                              width: 100, height: 100,
                              decoration: BoxDecoration(
                                color: context.cardBg,
                                shape: BoxShape.circle,
                                border: Border.all(color: context.borderColor.withValues(alpha: 0.3)),
                                image: _photoFile != null
                                    ? DecorationImage(image: FileImage(_photoFile!), fit: BoxFit.cover)
                                    : null,
                              ),
                              child: _photoFile == null
                                  ? Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.camera_alt_rounded, color: context.textTertiaryColor, size: 28),
                                        const SizedBox(height: 4),
                                        Text('Add Photo', style: TextStyle(color: context.textTertiaryColor, fontSize: 10)),
                                      ],
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Personal Info section
                        Text('Personal Information', style: AppTypography.titleMedium),
                        const SizedBox(height: 14),
                        GlassContainer(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildField('Full Name', _nameController, Icons.person_rounded, 'Student name', validator: Validators.name),
                              const SizedBox(height: 16),
                              _buildField('Student Unique ID', _uniqueIdController, Icons.qr_code_2_rounded, 'Auto-generated — share with student', inputType: TextInputType.text),
                              const SizedBox(height: 16),
                              _buildField('Phone Number', _phoneController, Icons.phone_rounded, '+91 9876543210', inputType: TextInputType.phone),
                              const SizedBox(height: 16),
                              _buildField('Parent Phone', _parentPhoneController, Icons.people_rounded, '+91 9876543210', inputType: TextInputType.phone),
                              const SizedBox(height: 16),
                              Text('Address', style: AppTypography.labelLarge),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _addressController,
                                maxLines: 2,
                                decoration: const InputDecoration(
                                  hintText: 'Full address...',
                                  prefixIcon: Padding(padding: EdgeInsets.only(bottom: 24), child: Icon(Icons.place_rounded)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Seat section
                        Text('Seat Allocation', style: AppTypography.titleMedium),
                        const SizedBox(height: 14),
                        GlassContainer(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Seat Category', style: AppTypography.labelLarge),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 10, runSpacing: 10,
                                children: ['Normal', 'AC', 'Premium', 'Cabin'].map((cat) {
                                  final isSelected = _selectedSeatCategory == cat;
                                  return GestureDetector(
                                    onTap: () => setState(() => _selectedSeatCategory = cat),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isSelected ? AppColors.primary : context.cardBg,
                                        borderRadius: BorderRadius.circular(10),
                                        border: !isSelected ? Border.all(color: context.borderColor.withValues(alpha: 0.3)) : null,
                                      ),
                                      child: Text(cat, style: AppTypography.labelMedium.copyWith(
                                        color: isSelected ? Colors.white : context.textSecondaryColor)),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Fee section
                        Text('Fee Details', style: AppTypography.titleMedium),
                        const SizedBox(height: 14),
                        GlassContainer(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Fee Plan', style: AppTypography.labelLarge),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 10, runSpacing: 10,
                                children: ['Monthly', 'Quarterly', 'Half-Yearly', 'Yearly'].map((plan) {
                                  final isSelected = _selectedFeePlan == plan;
                                  return GestureDetector(
                                    onTap: () => setState(() => _selectedFeePlan = plan),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isSelected ? AppColors.accent : context.cardBg,
                                        borderRadius: BorderRadius.circular(10),
                                        border: !isSelected ? Border.all(color: context.borderColor.withValues(alpha: 0.3)) : null,
                                      ),
                                      child: Text(plan, style: AppTypography.labelMedium.copyWith(
                                        color: isSelected ? Colors.white : context.textSecondaryColor)),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 16),
                              _buildField('Fee Amount', _feeAmountController, Icons.payments_rounded, '2500', inputType: TextInputType.number),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ID Proof text field
                        Text('ID Proof', style: AppTypography.titleMedium),
                        const SizedBox(height: 14),
                        GlassContainer(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildField('ID Proof Number', _idProofController, Icons.badge_rounded, 'Aadhaar / PAN / Voter ID / Passport', inputType: TextInputType.text),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Save button
                        NeonButton(
                          text: widget.isEditing ? 'Update Student' : 'Add Student',
                          onPressed: _onSave,
                          isLoading: _isLoading,
                          width: double.infinity,
                          icon: Icons.check_rounded,
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon, String hint,
      {TextInputType inputType = TextInputType.text, String? Function(String?)? validator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.labelLarge),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: inputType,
          validator: validator,
          decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icon)),
        ),
      ],
    );
  }
}
