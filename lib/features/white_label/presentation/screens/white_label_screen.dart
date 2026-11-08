import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class WhiteLabelScreen extends ConsumerStatefulWidget {
  const WhiteLabelScreen({super.key});

  @override
  ConsumerState<WhiteLabelScreen> createState() => _WhiteLabelScreenState();
}

class _WhiteLabelScreenState extends ConsumerState<WhiteLabelScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _taglineController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  Color _primaryColor = const Color(0xFF6366F1); // Indigo
  Color _secondaryColor = const Color(0xFF8B5CF6); // Purple
  String _selectedTier = 'standard_4999'; // 'standard_4999' or 'premium_9999'
  bool _submitting = false;

  final List<Map<String, dynamic>> _colorPresets = [
    {
      'name': 'Royal Indigo',
      'primary': const Color(0xFF6366F1),
      'secondary': const Color(0xFF8B5CF6),
    },
    {
      'name': 'Emerald Green',
      'primary': const Color(0xFF10B981),
      'secondary': const Color(0xFF059669),
    },
    {
      'name': 'Cyber Neon',
      'primary': const Color(0xFF06B6D4),
      'secondary': const Color(0xFF3B82F6),
    },
    {
      'name': 'Crimson Lux',
      'primary': const Color(0xFFEF4444),
      'secondary': const Color(0xFFEC4899),
    },
    {
      'name': 'Gold Elite',
      'primary': const Color(0xFFF59E0B),
      'secondary': const Color(0xFFD97706),
    },
  ];

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    if (user != null) {
      _nameController.text = user.displayName;
      _emailController.text = user.email ?? '';
    }
    _taglineController.text = 'Study Room & Reading Library';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _taglineController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    try {
      final user = ref.read(currentUserProvider);
      final reqId = 'wl_${DateTime.now().millisecondsSinceEpoch}';

      await FirebaseFirestore.instance.collection('white_label_requests').doc(reqId).set({
        'requestId': reqId,
        'ownerId': user?.uid ?? 'unknown',
        'libraryName': _nameController.text.trim(),
        'tagline': _taglineController.text.trim(),
        'primaryColorHex': '#${_primaryColor.toARGB32().toRadixString(16)}',
        'secondaryColorHex': '#${_secondaryColor.toARGB32().toRadixString(16)}',
        'packageTier': _selectedTier,
        'packagePrice': _selectedTier == 'standard_4999' ? '₹4,999' : '₹9,999',
        'contactPhone': _phoneController.text.trim(),
        'contactEmail': _emailController.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: context.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.check_circle_rounded, color: AppColors.success),
              ),
              const SizedBox(width: 12),
              Text(
                'Order Submitted!',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          content: Text(
            'Your White-Label App setup request has been logged. Our developer team will contact you at ${_phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : _emailController.text.trim()} to deliver your custom branded app.',
            style: AppTypography.bodySmall.copyWith(color: context.textSecondaryColor),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit order: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App bar header
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('White-Label App Studio', style: AppTypography.headlineSmall),
                          Text('Get your own branded Play Store App', style: AppTypography.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Live Phone Mockup Preview
                _buildLivePhoneMockup(),
                const SizedBox(height: 24),

                // Package Selection (Standard vs Premium Play Store)
                Text('Select Package Tier', style: AppTypography.titleMedium),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTierCard(
                        id: 'standard_4999',
                        title: 'Standard App',
                        price: '₹4,999',
                        subtitle: 'Custom APK + Splash + Brand Theme',
                        icon: Icons.android_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTierCard(
                        id: 'premium_9999',
                        title: 'Play Store Package',
                        price: '₹9,999',
                        subtitle: 'Full Play Store Listing + Dedicated App',
                        icon: Icons.shop_two_rounded,
                        isPopular: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Custom Brand Details Form
                Text('Custom Branding Details', style: AppTypography.titleMedium),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
                  onChanged: (_) => setState(() {}),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Library name is required' : null,
                  decoration: _buildInputDeco('Library App Name', Icons.storefront_rounded),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _taglineController,
                  style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
                  onChanged: (_) => setState(() {}),
                  decoration: _buildInputDeco('App Slogan / Tagline', Icons.label_important_outline_rounded),
                ),
                const SizedBox(height: 20),

                // Brand Color Theme Selection
                Text('Brand Color Palette', style: AppTypography.titleMedium),
                const SizedBox(height: 10),
                SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _colorPresets.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final preset = _colorPresets[index];
                      final isSelected = _primaryColor == preset['primary'];
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _primaryColor = preset['primary'];
                            _secondaryColor = preset['secondary'];
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [preset['primary'], preset['secondary']],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 2,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: preset['primary'].withValues(alpha: 0.5),
                                      blurRadius: 10,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              preset['name'],
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Contact Details
                Text('Contact Details for App Delivery', style: AppTypography.titleMedium),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Phone number is required' : null,
                  decoration: _buildInputDeco('WhatsApp / Phone Number', Icons.phone_android_rounded),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Email is required' : null,
                  decoration: _buildInputDeco('Email Address', Icons.email_outlined),
                ),
                const SizedBox(height: 28),

                // Submit Request Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submitRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            'Request Custom Branded App (${_selectedTier == 'standard_4999' ? '₹4,999' : '₹9,999'})',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLivePhoneMockup() {
    final appTitle = _nameController.text.trim().isEmpty
        ? 'Sunrise Study Library'
        : _nameController.text.trim();
    final tagline = _taglineController.text.trim().isEmpty
        ? 'Reading Room & Study Hub'
        : _taglineController.text.trim();

    return Center(
      child: Container(
        width: 260,
        height: 380,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: context.borderColor.withValues(alpha: 0.4), width: 6),
          boxShadow: [
            BoxShadow(
              color: _primaryColor.withValues(alpha: 0.25),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            // Notch
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 80,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 12),

            // Live Branded Header
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primaryColor, _secondaryColor],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    appTitle,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    tagline,
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Live Phone Mockup Content
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 36,
                            decoration: BoxDecoration(
                              color: _primaryColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Text(
                                'Seat Map',
                                style: TextStyle(fontSize: 10, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            height: 36,
                            decoration: BoxDecoration(
                              color: _secondaryColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Text(
                                'Attendance',
                                style: TextStyle(fontSize: 10, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_primaryColor, _secondaryColor],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text(
                          'YOUR CUSTOM APP',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTierCard({
    required String id,
    required String title,
    required String price,
    required String subtitle,
    required IconData icon,
    bool isPopular = false,
  }) {
    final isSelected = _selectedTier == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedTier = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : context.borderColor.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isPopular)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'RECOMMENDED',
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: AppColors.accent),
                ),
              ),
            Icon(icon, color: isSelected ? AppColors.primary : context.textSecondaryColor, size: 24),
            const SizedBox(height: 8),
            Text(title, style: AppTypography.labelMedium),
            Text(
              price,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: AppTypography.bodySmall),
          ],
        ),
      ),
    );
  }

  InputDecoration _buildInputDeco(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(fontSize: 14, color: context.textTertiaryColor),
      prefixIcon: Icon(icon, color: context.textTertiaryColor, size: 20),
      filled: true,
      fillColor: context.cardBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: context.borderColor.withValues(alpha: 0.2)),
      ),
    );
  }
}
