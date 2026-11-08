import 'package:flutter/cupertino.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';

/// iOS form-group profile creation screen using a native inset grouped form.
class ProfileCreateScreen extends ConsumerStatefulWidget {
  const ProfileCreateScreen({super.key});

  @override
  ConsumerState<ProfileCreateScreen> createState() => _ProfileCreateScreenState();
}

class _ProfileCreateScreenState extends ConsumerState<ProfileCreateScreen> {
  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _parentMobileCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final authName = ref.read(authProvider).name;
    final googleName = FirebaseAuth.instance.currentUser?.displayName;
    final initialName = authName ?? googleName ?? '';
    if (initialName.isNotEmpty) {
      _nameCtrl.text = initialName;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _addressCtrl.dispose();
    _parentMobileCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final error = await ref.read(authProvider.notifier).createProfile(
          name: _nameCtrl.text.trim(),
          mobile: _mobileCtrl.text.trim(),
          parentMobile: _parentMobileCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
        );

    if (error == null && mounted) {
      // Land on the home screen after creating the profile. The dashboard
      // shows the "No Library Joined" state with the QR-scan button in the
      // navigation bar and the Nearby tab — joining a library is optional and
      // never forced right after sign-up.
      context.go('/dashboard');
    } else if (error != null && mounted) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Error'),
          content: Text(error),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  String? _phone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final digits = v.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return 'Enter a valid 10-digit number';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final accountEmail = FirebaseAuth.instance.currentUser?.email ?? '';

    return CupertinoPageScaffold(
      backgroundColor: AppColors.systemGroupedBackground,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.systemGray5,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    CupertinoIcons.person_crop_circle,
                    size: 36,
                    color: AppColors.systemBlue,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Complete Your Profile',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.label,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Fill your details to continue',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.secondaryLabel,
                  ),
                ),
                if (accountEmail.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    accountEmail,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.tertiaryLabel,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                CupertinoFormSection(
                  header: const Text('Student Details'),
                  children: [
                    CupertinoTextFormFieldRow(
                      controller: _nameCtrl,
                      placeholder: 'Full Name',
                      prefix: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Icon(
                          CupertinoIcons.person_solid,
                          color: AppColors.secondaryLabel,
                          size: 20,
                        ),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: _required,
                    ),
                    CupertinoTextFormFieldRow(
                      controller: _mobileCtrl,
                      keyboardType: TextInputType.phone,
                      maxLength: 15,
                      placeholder: 'Mobile Number',
                      prefix: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Icon(
                          CupertinoIcons.phone_solid,
                          color: AppColors.secondaryLabel,
                          size: 20,
                        ),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: _phone,
                    ),
                    CupertinoTextFormFieldRow(
                      controller: _addressCtrl,
                      placeholder: 'Address',
                      prefix: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Icon(
                          CupertinoIcons.house_fill,
                          color: AppColors.secondaryLabel,
                          size: 20,
                        ),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: _required,
                    ),
                    CupertinoTextFormFieldRow(
                      controller: _parentMobileCtrl,
                      keyboardType: TextInputType.phone,
                      maxLength: 15,
                      placeholder: "Parent's Mobile Number",
                      prefix: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Icon(
                          CupertinoIcons.person_2_fill,
                          color: AppColors.secondaryLabel,
                          size: 20,
                        ),
                      ),
                      textInputAction: TextInputAction.done,
                      validator: _phone,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    borderRadius: BorderRadius.circular(14),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    onPressed: authState.isLoading ? null : _submit,
                    child: authState.isLoading
                        ? const CupertinoActivityIndicator(
                            color: CupertinoColors.white)
                        : const Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: authState.isLoading
                      ? null
                      : () async {
                          await ref.read(authProvider.notifier).logout();
                        },
                  child: const Text(
                    'Sign Out & Use Another Account',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
