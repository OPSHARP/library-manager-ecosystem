import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/services/geocode_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/neon_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';

/// Lets the library owner publish ("ping") their library location so it is
/// shown to all students on the student app's "Nearby Libraries" map. The
/// owner can update or clear the location at any time.
class LibraryLocationScreen extends ConsumerStatefulWidget {
  const LibraryLocationScreen({super.key});

  @override
  ConsumerState<LibraryLocationScreen> createState() => _LibraryLocationScreenState();
}

class _LibraryLocationScreenState extends ConsumerState<LibraryLocationScreen> {
  bool _isLoading = false;
  bool _isSaving = false;
  double? _latitude;
  double? _longitude;
  String _address = '';
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLocation());
  }

  String? get _libraryId {
    final user = ref.read(currentUserProvider);
    return user != null ? 'lib_${user.uid}' : null;
  }

  Future<void> _loadLocation() async {
    final libraryId = _libraryId;
    if (libraryId == null) return;
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(libraryRepositoryProvider);
      final location = await repo.getLibraryLocation(libraryId);
      if (mounted && location != null) {
        setState(() {
          _latitude = location['latitude'] as double?;
          _longitude = location['longitude'] as double?;
          _address = location['address'] as String? ?? '';
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

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

  Future<void> _pingCurrentLocation() async {
    final position = await _determinePosition();
    if (position == null) return;
    setState(() => _isSaving = true);
    String address = _address;
    try {
      final resolved =
          await GeocodeService.reverseGeocode(position.latitude, position.longitude);
      if (resolved != null && resolved.isNotEmpty) address = resolved;
    } catch (_) {}
    await _saveLocation(position.latitude, position.longitude, address);
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _setByAddress() async {
    final controller = TextEditingController(text: _address);
    final address = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Set Library Location by Address'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter your library address',
            prefixIcon: Icon(Icons.place_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Search'),
          ),
        ],
      ),
    );
    if (address == null || address.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final coords = await GeocodeService.geocode(address);
      if (coords == null) {
        if (mounted) {
          setState(() => _isSaving = false);
          _showSnack('Could not find that address. Try again.', isError: true);
        }
        return;
      }
      await _saveLocation(coords[0], coords[1], address);
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showSnack('Could not find that address. Try again.', isError: true);
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _saveLocation(double lat, double lng, String address) async {
    final user = ref.read(currentUserProvider);
    final libraryId = _libraryId;
    if (user == null || libraryId == null) return;
    try {
      final repo = ref.read(libraryRepositoryProvider);
      await repo.updateLibraryLocation(
        libraryId: libraryId,
        ownerUid: user.uid,
        latitude: lat,
        longitude: lng,
        address: address,
      );
      if (mounted) {
        setState(() {
          _latitude = lat;
          _longitude = lng;
          _address = address;
          _statusMessage = 'Location published! All students can now see your library on the map.';
        });
        _showSnack('Library location published successfully.');
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Failed to publish location. Please try again.';
        if (e.toString().contains('permission-denied')) {
          msg = 'Permission denied. If you recently updated the app, please ensure your Play Console SHA-256 is added to Firebase.';
        }
        _showSnack(msg, isError: true);
      }
    }
  }

  Future<void> _removeLocation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove from Nearby Map?'),
        content: const Text(
          'Your library will no longer appear on the student app\'s Nearby Libraries map. You can publish your location again at any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final user = ref.read(currentUserProvider);
    final libraryId = _libraryId;
    if (user == null || libraryId == null) return;

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(libraryRepositoryProvider);
      await repo.removeLibraryLocation(libraryId);
      if (mounted) {
        setState(() {
          _latitude = null;
          _longitude = null;
          _address = '';
          _statusMessage = null;
        });
        _showSnack('Library location removed from Nearby map.');
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Failed to remove location. Please try again.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _openInMaps() async {
    final lat = _latitude;
    final lng = _longitude;
    final uri = lat != null && lng != null
        ? Uri.parse(
            'https://www.google.com/maps?q=$lat,$lng')
        : Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(_address)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: AppTypography.bodyMedium.copyWith(color: Colors.white)),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasLocation = _latitude != null && _longitude != null;

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
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: 8),
                    Text('Library Location', style: AppTypography.headlineSmall),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      _buildStatusCard(context, hasLocation),
                      const SizedBox(height: 20),
                      Text('Update your location', style: AppTypography.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        'This location is shown to all students in the Nearby Libraries map.',
                        style: AppTypography.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      NeonButton(
                        text: 'Ping My Current Location',
                        icon: Icons.my_location_rounded,
                        isLoading: _isSaving,
                        onPressed: _isSaving ? null : _pingCurrentLocation,
                        width: double.infinity,
                      ),
                      const SizedBox(height: 12),
                      NeonButton(
                        text: 'Set Location by Address',
                        icon: Icons.edit_location_alt_rounded,
                        color: AppColors.secondary,
                        isOutlined: true,
                        onPressed: _isSaving ? null : _setByAddress,
                        width: double.infinity,
                      ),
                      if (hasLocation) ...[
                        const SizedBox(height: 12),
                        NeonButton(
                          text: 'Open in Maps',
                          icon: Icons.map_rounded,
                          color: AppColors.accent,
                          isOutlined: true,
                          onPressed: _openInMaps,
                          width: double.infinity,
                        ),
                        const SizedBox(height: 12),
                        NeonButton(
                          text: 'Remove from Nearby Map',
                          icon: Icons.location_off_rounded,
                          color: AppColors.error,
                          isOutlined: true,
                          isLoading: _isSaving,
                          onPressed: _isSaving ? null : _removeLocation,
                          width: double.infinity,
                        ),
                      ],
                      if (_statusMessage != null) ...[
                        const SizedBox(height: 16),
                        _buildStatusBanner(context),
                      ],
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

  Widget _buildStatusCard(BuildContext context, bool hasLocation) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: hasLocation
                            ? AppGradients.primaryGradient
                            : null,
                        color: hasLocation ? null : context.cardBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        hasLocation
                            ? Icons.location_on_rounded
                            : Icons.location_off_rounded,
                        color: hasLocation ? Colors.white : context.textTertiaryColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasLocation ? 'Location Published' : 'No Location Set',
                            style: AppTypography.titleMedium.copyWith(
                              color: hasLocation ? AppColors.success : context.textTertiaryColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hasLocation
                                ? 'Students can see your library on the map'
                                : 'Ping your location so students can find you',
                            style: AppTypography.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (hasLocation) ...[
                  const SizedBox(height: 16),
                  Divider(color: context.borderColor.withValues(alpha: 0.3)),
                  const SizedBox(height: 12),
                  if (_address.isNotEmpty)
                    _infoRow(Icons.place_rounded, _address),
                  _infoRow(
                    Icons.gps_fixed_rounded,
                    '${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}',
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildStatusBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_statusMessage!,
                style: AppTypography.bodyMedium.copyWith(color: AppColors.success)),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: context.textSecondaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: AppTypography.bodyMedium.copyWith(color: context.textSecondaryColor)),
          ),
        ],
      ),
    );
  }
}
