import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/neon_button.dart';
import '../../../../core/services/image_upload_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../seats/presentation/providers/seat_provider.dart';
import '../../data/models/library_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Library Setup Screen
class LibrarySetupScreen extends ConsumerStatefulWidget {
  const LibrarySetupScreen({super.key});

  @override
  ConsumerState<LibrarySetupScreen> createState() => _LibrarySetupScreenState();
}

class _LibrarySetupScreenState extends ConsumerState<LibrarySetupScreen> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactController = TextEditingController();
  final _capacityController = TextEditingController();
  final _facilityController = TextEditingController();
  final List<String> _facilities = [];
  bool _isLoading = false;

    Future<Position?> _determinePosition() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission is required to fetch location.')),
        );
      }
      return null;
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled. Please turn on GPS.')),
        );
      }
      await Geolocator.openLocationSettings();
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (_) {
      return null;
    }
  }
  bool _isUploadingLogo = false;

  /// Local file for immediate preview after picking.
  File? _logoFile;

  /// Firebase Storage download URL (set after upload completes, or loaded from
  /// existing library data).
  String? _logoUrl;

  @override
  void initState() {
    super.initState();
    // Pre-fill fields if the library already exists.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExisting());
  }

  Future<void> _loadExisting() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final repo = ref.read(libraryRepositoryProvider);
    final lib = await repo.getLibrarySync('lib_${user.uid}');
    if (lib != null && mounted) {
      setState(() {
        _nameController.text = lib.libraryName;
        _addressController.text = lib.address;
        _contactController.text = lib.contactNumber;
        _capacityController.text =
            lib.seatCapacity > 0 ? lib.seatCapacity.toString() : '';
        _logoUrl = lib.logoUrl;
        _facilities
          ..clear()
          ..addAll(lib.facilities);
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    _capacityController.dispose();
    _facilityController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadLogo() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isUploadingLogo = true);
    try {
      final service = ref.read(imageUploadServiceProvider);

      // First pick so we can show a local preview immediately.
      final file = await service.pickLogoImage();
      if (file == null) {
        if (mounted) setState(() => _isUploadingLogo = false);
        return;
      }
      if (mounted) setState(() => _logoFile = file);

      // Upload to Firebase Storage.
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
            content: Text(e.message,
                style:
                    AppTypography.bodyMedium.copyWith(color: Colors.white)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload logo. Please try again.',
                style:
                    AppTypography.bodyMedium.copyWith(color: Colors.white)),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingLogo = false);
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
                    Text('Library Setup', style: AppTypography.headlineSmall),
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
                      // Logo upload
                      Center(
                        child: GestureDetector(
                          onTap: _isUploadingLogo ? null : _pickAndUploadLogo,
                          child: Container(
                            width: 100, height: 100,
                            decoration: BoxDecoration(
                              gradient: (_logoFile == null && _logoUrl == null)
                                  ? AppGradients.primaryGradient
                                  : null,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 20)],
                              image: _logoFile != null
                                  ? DecorationImage(image: FileImage(_logoFile!), fit: BoxFit.cover)
                                  : _logoUrl != null
                                      ? DecorationImage(image: NetworkImage(_logoUrl!), fit: BoxFit.cover)
                                      : null,
                            ),
                            child: _isUploadingLogo
                                ? const Center(
                                    child: SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                : (_logoFile == null && _logoUrl == null)
                                    ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                        Icon(Icons.local_library_rounded, color: Colors.white, size: 36),
                                        SizedBox(height: 4),
                                        Text('Upload Logo', style: TextStyle(color: Colors.white70, fontSize: 10)),
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
                      ),
                      if (_logoFile == null && _logoUrl == null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Center(
                            child: Text(
                              'Logo must be 20-50 KB',
                              style: AppTypography.labelSmall.copyWith(color: context.textTertiaryColor),
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),

                      Text('Library Information', style: AppTypography.titleMedium),
                      const SizedBox(height: 14),
                      GlassContainer(
                        padding: const EdgeInsets.all(20),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _field('Library Name', _nameController, Icons.local_library_rounded),
                          const SizedBox(height: 16),
                          _field('Address', _addressController, Icons.place_rounded),
                          const SizedBox(height: 16),
                          _field('Contact Number', _contactController, Icons.phone_rounded),
                          const SizedBox(height: 16),
                          _field('Seat Capacity', _capacityController, Icons.chair_rounded),
                        ]),
                      ),
                      const SizedBox(height: 20),

                      Text('Facilities', style: AppTypography.titleMedium),
                      const SizedBox(height: 14),
                      GlassContainer(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _facilityController,
                                    decoration: const InputDecoration(
                                      prefixIcon: Icon(Icons.celebration_rounded),
                                      hintText: 'e.g. AC, Wi-Fi, Drinking Water',
                                    ),
                                    onSubmitted: (_) => _addFacility(),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_rounded,
                                      color: AppColors.primary),
                                  tooltip: 'Add facility',
                                  onPressed: _addFacility,
                                ),
                              ],
                            ),
                            if (_facilities.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _facilities.map((f) {
                                  return InputChip(
                                    label: Text(f),
                                    deleteIcon: const Icon(Icons.close_rounded,
                                        size: 16),
                                    onDeleted: () {
                                      setState(() => _facilities.remove(f));
                                    },
                                  );
                                }).toList(),
                              ),
                            ] else
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'No facilities added yet. Students will see these when searching your library.',
                                  style: AppTypography.labelSmall
                                      .copyWith(color: context.textTertiaryColor),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      Text('Working Hours', style: AppTypography.titleMedium),
                      const SizedBox(height: 14),
                      GlassContainer(
                        padding: const EdgeInsets.all(20),
                        child: Row(children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Opens', style: AppTypography.labelMedium),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(10)),
                              child: Row(children: [
                                Icon(Icons.schedule_rounded, size: 18, color: context.textTertiaryColor),
                                const SizedBox(width: 8),
                                Text('09:00 AM', style: AppTypography.bodyMedium),
                              ]),
                            ),
                          ])),
                          const SizedBox(width: 16),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Closes', style: AppTypography.labelMedium),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(10)),
                              child: Row(children: [
                                Icon(Icons.schedule_rounded, size: 18, color: context.textTertiaryColor),
                                const SizedBox(width: 8),
                                Text('10:00 PM', style: AppTypography.bodyMedium),
                              ]),
                            ),
                          ])),
                        ]),
                      ),
                      const SizedBox(height: 32),

                      NeonButton(
                        text: 'Save Changes',
                        isLoading: _isLoading,
                        onPressed: () async {
                          if (_nameController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Library name is required', style: AppTypography.bodyMedium.copyWith(color: Colors.white)), backgroundColor: AppColors.error),
                            );
                            return;
                          }
                          setState(() => _isLoading = true);
                          try {
                            final user = ref.read(currentUserProvider);
                            final repo = ref.read(libraryRepositoryProvider);
                            if (user == null) {
                              throw Exception(
                                  'Not signed in — please sign in again and retry');
                            }
                            final uid = user.uid;
                            final libraryId = 'lib_$uid';

                            // Get existing library to preserve code/QR
                            final existing = await repo.getLibrarySync(libraryId);
                            final code = existing?.libraryCode ?? await repo.generateUniqueCode();
                            final qrData = existing?.qrData ??
                                '{"ownerUid":"$uid","libraryId":"$libraryId","libraryCode":"$code"}';

                            final library = LibraryModel(
                              libraryId: libraryId,
                              ownerId: uid,
                              libraryName: _nameController.text.trim(),
                              address: _addressController.text.trim(),
                              contactNumber: _contactController.text.trim(),
                              seatCapacity: int.tryParse(_capacityController.text) ?? 100,
                              availableSeats: int.tryParse(_capacityController.text) ?? 100,
                              currency: existing?.currency ?? '\$',
                              libraryCode: code,
                              qrData: qrData,
                              logoUrl: _logoUrl ?? existing?.logoUrl,
                              bannerUrl: existing?.bannerUrl,
                              createdAt: existing?.createdAt ?? DateTime.now(),
                              updatedAt: DateTime.now(),
                            );
                            await repo.updateLibrary(libraryId, library);
                            
                            Position? position;
                            try {
                              position = await _determinePosition();
                            } catch (_) {
                              position = null;
                            }

                            await repo.registerLibraryCode(
                              code, uid, libraryId, library.libraryName,
                              contactNumber: library.contactNumber,
                              address: library.address,
                              latitude: position?.latitude,
                              longitude: position?.longitude,
                              seatCapacity: library.seatCapacity,
                              facilities: List<String>.from(_facilities),
                            );
                            // Keep the public "available seats" counter in sync
                            // with the owner's seat records.
                            unawaited(ref.read(seatRepositoryProvider).syncSeatAvailability());
                            if (mounted) {
                              setState(() => _isLoading = false);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Library saved successfully', style: AppTypography.bodyMedium.copyWith(color: Colors.white)), backgroundColor: AppColors.accent),
                              );
                              context.pop();
                            }
                          } catch (e) {
                            if (!mounted) return;
                            setState(() => _isLoading = false);
                            if (mounted && context.mounted) {
                              String msg = 'Could not save library details. Please try again.';
                              if (e.toString().contains('permission-denied')) {
                                msg = 'Permission denied. If you recently updated the app, please ensure your Play Console SHA-256 is added to Firebase.';
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(msg, style: AppTypography.bodyMedium.copyWith(color: Colors.white)), 
                                  backgroundColor: AppColors.error,
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            }
                          }
                        },
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

  void _addFacility() {
    final value = _facilityController.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _facilities.add(value);
      _facilityController.clear();
    });
  }

  Widget _field(String label, TextEditingController controller, IconData icon) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppTypography.labelLarge),
      const SizedBox(height: 8),
      TextFormField(controller: controller, decoration: InputDecoration(prefixIcon: Icon(icon), hintText: 'Enter $label')),
    ]);
  }
}
