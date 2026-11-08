import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../auth/presentation/providers/auth_provider.dart';

/// Lets the student edit their own name, phone, parent phone and address.
///
/// The changes are saved to the student's own Firestore profile doc
/// (`student_profiles/{profileId}`) and the local secure session.
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _mobileCtrl;
  late final TextEditingController _parentCtrl;
  late final TextEditingController _addressCtrl;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authProvider);
    _nameCtrl = TextEditingController(text: auth.name ?? '');
    _mobileCtrl = TextEditingController(text: auth.mobile ?? '');
    _parentCtrl = TextEditingController(text: auth.parentMobile ?? '');
    _addressCtrl = TextEditingController(text: auth.address ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _parentCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();

    final error = await ref.read(authProvider.notifier).updateProfile(
          name: _nameCtrl.text.trim(),
          mobile: _mobileCtrl.text.trim(),
          parentMobile: _parentCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
        );

    if (!mounted) return;
    if (error == null) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Profile Updated'),
          content: const Text('Your details have been saved.'),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
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
    if (v.trim().length < 10) return 'Enter a valid number';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return CupertinoPageScaffold(
      backgroundColor: AppColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.floatingBar,
        middle: const Text('Edit Profile'),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Update the details shown to your library.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.secondaryLabel,
                  ),
                ),
                const SizedBox(height: 16),
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
                      controller: _parentCtrl,
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
                      textInputAction: TextInputAction.done,
                      validator: _required,
                      onFieldSubmitted: (_) => _save(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    borderRadius: BorderRadius.circular(14),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    onPressed: authState.isLoading ? null : _save,
                    child: authState.isLoading
                        ? const CupertinoActivityIndicator(
                            color: CupertinoColors.white)
                        : const Text(
                            'Save Changes',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
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
