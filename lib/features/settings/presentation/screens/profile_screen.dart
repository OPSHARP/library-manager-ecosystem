import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Profile Screen
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _libraryNameController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final user = ref.read(currentUserProvider);
    if (mounted) {
      setState(() {
        _nameController.text = user?.displayName ?? prefs.getString('auth_name') ?? '';
        _emailController.text = user?.email ?? prefs.getString('auth_email') ?? '';
        _libraryNameController.text = prefs.getString('library_name') ?? '';
        _cityController.text = prefs.getString('city') ?? '';
        _addressController.text = prefs.getString('address') ?? '';
      });
    }
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);

    // Use updateProfile to persist to both SharedPreferences and Firestore
    await ref.read(authProvider.notifier).updateProfile(
      name: _nameController.text.trim(),
      email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
      libraryName: _libraryNameController.text.trim(),
      city: _cityController.text.trim(),
      address: _addressController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile saved successfully'), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _libraryNameController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final name = _nameController.text.isNotEmpty ? _nameController.text : (user?.displayName ?? 'Library Owner');
    var initials = name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase();
    if (initials.isEmpty) initials = 'LM';

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
                    Text('Profile', style: AppTypography.headlineSmall),
                    const Spacer(),
                    TextButton(
                      onPressed: _isLoading ? null : _save,
                      child: _isLoading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text('Save', style: AppTypography.labelLarge.copyWith(color: AppColors.primary)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      // Avatar
                      Stack(
                        children: [
                          Container(
                            width: 100, height: 100,
                            decoration: BoxDecoration(gradient: AppGradients.primaryGradient, shape: BoxShape.circle),
                            child: Center(child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 32))),
                          ),
                          Positioned(
                            bottom: 0, right: 0,
                            child: Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, border: Border.all(color: context.scaffoldBg, width: 3)),
                              child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      _ProfileField(label: 'Full Name', controller: _nameController, icon: Icons.person_rounded),
                      _ProfileField(label: 'Email', controller: _emailController, icon: Icons.email_rounded, keyboardType: TextInputType.emailAddress),
                      _ProfileField(label: 'Library Name', controller: _libraryNameController, icon: Icons.local_library_rounded),
                      _ProfileField(label: 'City', controller: _cityController, icon: Icons.location_city_rounded),
                      _ProfileField(label: 'Address', controller: _addressController, icon: Icons.place_rounded),
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
}

class _ProfileField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final TextInputType? keyboardType;
  const _ProfileField({required this.label, required this.controller, required this.icon, this.keyboardType});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.labelMedium),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(prefixIcon: Icon(icon)),
          ),
        ],
      ),
    );
  }
}
