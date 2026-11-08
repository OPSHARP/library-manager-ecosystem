import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/neon_button.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/services/image_upload_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../data/models/library_model.dart';
import '../../data/repositories/library_repository.dart';

class LibraryBrandingScreen extends ConsumerStatefulWidget {
  const LibraryBrandingScreen({super.key});

  @override
  ConsumerState<LibraryBrandingScreen> createState() => _LibraryBrandingScreenState();
}

class _LibraryBrandingScreenState extends ConsumerState<LibraryBrandingScreen> {
  Color _selectedColor = AppColors.primary;

  final _colors = [
    AppColors.primary,
    AppColors.secondary,
    AppColors.accent,
    AppColors.neonPink,
    AppColors.neonPurple,
    AppColors.neonBlue,
    const Color(0xFFFF6B6B),
    const Color(0xFFFFA500),
  ];

  // Logo state
  File? _logoFile;
  String? _logoUrl;
  bool _isUploadingLogo = false;

  // Banner state
  File? _bannerFile;
  String? _bannerUrl;
  bool _isUploadingBanner = false;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExisting());
  }

  Future<void> _loadExisting() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final repo = ref.read(libraryRepositoryProvider);
    final lib = await repo.getLibrarySync('lib_${user.uid}');
    if (lib != null && mounted) {
      setState(() {
        _logoUrl = lib.logoUrl;
        _bannerUrl = lib.bannerUrl;
        if (lib.themeColor != null) {
          final parsed = int.tryParse(lib.themeColor!, radix: 16);
          if (parsed != null) {
            _selectedColor = Color(parsed);
          }
        }
      });
    }
  }

  Future<void> _pickAndUploadLogo() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isUploadingLogo = true);
    try {
      final service = ref.read(imageUploadServiceProvider);
      final file = await service.pickLogoImage();
      if (file == null) {
        if (mounted) setState(() => _isUploadingLogo = false);
        return;
      }
      if (mounted) setState(() => _logoFile = file);

      final ts = DateTime.now().millisecondsSinceEpoch;
      final url = await service.uploadFile(
        file,
        'library_images/${user.uid}/logo_$ts.jpg',
      );
      if (mounted) setState(() => _logoUrl = url);
    } on LogoSizeException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message, style: AppTypography.bodyMedium.copyWith(color: Colors.white)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload logo: $e', style: AppTypography.bodyMedium.copyWith(color: Colors.white)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingLogo = false);
    }
  }

  Future<void> _pickAndUploadBanner() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isUploadingBanner = true);
    try {
      final service = ref.read(imageUploadServiceProvider);
      final file = await service.pickBannerImage();
      if (file == null) {
        if (mounted) setState(() => _isUploadingBanner = false);
        return;
      }
      if (mounted) setState(() => _bannerFile = file);

      final ts = DateTime.now().millisecondsSinceEpoch;
      final url = await service.uploadFile(
        file,
        'library_images/${user.uid}/banner_$ts.jpg',
      );
      if (mounted) setState(() => _bannerUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload banner: $e', style: AppTypography.bodyMedium.copyWith(color: Colors.white)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingBanner = false);
    }
  }

  Future<void> _saveBranding() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(libraryRepositoryProvider);
      final libraryId = 'lib_${user.uid}';
      await repo.updateBranding(
        libraryId,
        logoUrl: _logoUrl,
        bannerUrl: _bannerUrl,
        themeColor: _selectedColor.toARGB32().toRadixString(16).padLeft(8, '0'),
      );
      if (mounted) {
        context.showSuccess('Branding updated');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save branding: $e', style: AppTypography.bodyMedium.copyWith(color: Colors.white)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final repo = ref.watch(libraryRepositoryProvider);
    final uid = user?.uid;

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
                    Text('Library Branding', style: AppTypography.headlineSmall),
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
                      Text('Preview', style: AppTypography.titleMedium),
                      const SizedBox(height: 14),
                      _buildPreviewCard(),
                      const SizedBox(height: 24),

                      // ── Logo ──
                      Text('Logo', style: AppTypography.titleMedium),
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: _isUploadingLogo ? null : _pickAndUploadLogo,
                        child: Container(
                          width: 100, height: 100,
                          decoration: BoxDecoration(
                            color: context.cardBg,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: context.borderColor.withValues(alpha: 0.3)),
                            image: _logoFile != null
                                ? DecorationImage(image: FileImage(_logoFile!), fit: BoxFit.cover)
                                : _logoUrl != null
                                    ? DecorationImage(image: NetworkImage(_logoUrl!), fit: BoxFit.cover)
                                    : null,
                          ),
                          child: _isUploadingLogo
                              ? const Center(
                                  child: SizedBox(
                                    width: 28, height: 28,
                                    child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
                                  ),
                                )
                              : (_logoFile == null && _logoUrl == null)
                                  ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                      Icon(Icons.camera_alt_rounded, color: AppColors.primary.withValues(alpha: 0.6), size: 32),
                                      const SizedBox(height: 4),
                                      Text('Upload', style: AppTypography.labelSmall),
                                    ])
                                  : Align(
                                      alignment: Alignment.bottomRight,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 1.5),
                                        ),
                                        child: const Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                                      ),
                                    ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Logo must be 20–50 KB',
                          style: AppTypography.labelSmall.copyWith(color: context.textTertiaryColor),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Banner ──
                      Text('Banner Image', style: AppTypography.titleMedium),
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: _isUploadingBanner ? null : _pickAndUploadBanner,
                        child: Container(
                          width: double.infinity, height: 120,
                          decoration: BoxDecoration(
                            color: context.cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: context.borderColor.withValues(alpha: 0.3)),
                            image: _bannerFile != null
                                ? DecorationImage(image: FileImage(_bannerFile!), fit: BoxFit.cover)
                                : _bannerUrl != null
                                    ? DecorationImage(image: NetworkImage(_bannerUrl!), fit: BoxFit.cover)
                                    : null,
                          ),
                          child: _isUploadingBanner
                              ? const Center(
                                  child: SizedBox(
                                    width: 28, height: 28,
                                    child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
                                  ),
                                )
                              : (_bannerFile == null && _bannerUrl == null)
                                  ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                      Icon(Icons.panorama_rounded, size: 40, color: AppColors.primary.withValues(alpha: 0.5)),
                                      const SizedBox(height: 8),
                                      Text('Upload Banner Image', style: AppTypography.labelMedium.copyWith(color: context.textTertiaryColor)),
                                      Text('Recommended: 1200x400', style: AppTypography.labelSmall),
                                    ])
                                  : Align(
                                      alignment: Alignment.topRight,
                                      child: Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 1.5),
                                          ),
                                          child: const Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                                        ),
                                      ),
                                    ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Theme Color ──
                      Text('Theme Color', style: AppTypography.titleMedium),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 12, runSpacing: 12,
                        children: _colors.map((color) {
                          final isSelected = _selectedColor == color;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedColor = color),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 48, height: 48,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 3),
                                boxShadow: isSelected ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 12)] : null,
                              ),
                              child: isSelected ? const Icon(Icons.check_rounded, color: Colors.white, size: 24) : null,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),

                      // ── QR Code ──
                      Text('Library QR Code', style: AppTypography.titleMedium),
                      const SizedBox(height: 14),
                      _buildQrSection(repo, uid),
                      const SizedBox(height: 32),

                      NeonButton(
                        text: 'Save Branding',
                        isLoading: _isSaving,
                        onPressed: _saveBranding,
                        width: double.infinity,
                        icon: Icons.check_rounded,
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

  Widget _buildPreviewCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_selectedColor, _selectedColor.withValues(alpha: 0.7)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _selectedColor.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                  image: _logoFile != null
                      ? DecorationImage(image: FileImage(_logoFile!), fit: BoxFit.cover)
                      : _logoUrl != null
                          ? DecorationImage(image: NetworkImage(_logoUrl!), fit: BoxFit.cover)
                          : null,
                ),
                child: (_logoFile == null && _logoUrl == null)
                    ? const Icon(Icons.local_library_rounded, color: Colors.white, size: 28)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Your Library", style: AppTypography.titleMedium.copyWith(color: Colors.white), overflow: TextOverflow.ellipsis),
                    Text('Set up your library', style: AppTypography.bodySmall.copyWith(color: Colors.white70), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _PreviewStat('Students', '0'),
              _PreviewStat('Seats', '0'),
              _PreviewStat('Rating', '—'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQrSection(LibraryRepository repo, String? uid) {
    if (uid == null) {
      return GlassContainer(
        padding: const EdgeInsets.all(20),
        child: const Center(child: Text('Loading...', style: TextStyle(color: AppColors.textSecondary))),
      );
    }

    return FutureBuilder<LibraryModel?>(
      future: repo.getLibrarySync('lib_$uid'),
      builder: (context, snapshot) {
        final library = snapshot.data;
        final libraryCode = library?.libraryCode;
        final qrData = library?.qrData;

        final displayCode = libraryCode ?? '---';
        final qrPayload = qrData ?? '{"ownerUid":"$uid"}';

        return GlassContainer(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 180, height: 180,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(12),
                child: QrImageView(
                  data: qrPayload,
                  version: QrVersions.auto,
                  size: 156,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
                ),
              ),
              const SizedBox(height: 16),
              Text('Library Code: $displayCode',
                  style: AppTypography.titleMedium.copyWith(color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text('Students scan this QR to join your library',
                  style: AppTypography.bodySmall, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text('Or enter code: $displayCode',
                  style: AppTypography.labelMedium.copyWith(color: AppColors.primary)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Download QR'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PreviewStat extends StatelessWidget {
  final String label;
  final String value;
  const _PreviewStat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: AppTypography.titleMedium.copyWith(color: Colors.white)),
          Text(label, style: AppTypography.labelSmall.copyWith(color: Colors.white70)),
        ],
      ),
    );
  }
}
