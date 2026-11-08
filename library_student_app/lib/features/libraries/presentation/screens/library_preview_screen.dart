import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Shows a preview of a library's public details (name, address, contact,
/// seats, location on map) BEFORE the student joins.
class LibraryPreviewScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> registryData;

  const LibraryPreviewScreen({super.key, required this.registryData});

  @override
  ConsumerState<LibraryPreviewScreen> createState() =>
      _LibraryPreviewScreenState();
}

class _LibraryPreviewScreenState extends ConsumerState<LibraryPreviewScreen> {
  bool _isJoining = false;

  String get _ownerUid => (widget.registryData['ownerUid'] ?? '').toString();

  String get _libraryId => (widget.registryData['libraryId'] ?? '').toString();

  String get _libraryName =>
      (widget.registryData['libraryName'] ?? 'Library').toString();

  String get _address => (widget.registryData['address'] ?? '').toString();

  String get _contactNumber =>
      (widget.registryData['contactNumber'] ?? '').toString();

  int get _seatCapacity {
    final raw = widget.registryData['seatCapacity'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return 0;
  }

  int get _availableSeats {
    final raw = widget.registryData['availableSeats'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return _seatCapacity > 0 ? _seatCapacity : 0;
  }

  List<String> get _facilities {
    final raw = widget.registryData['facilities'];
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    if (raw is String && raw.isNotEmpty) {
      return raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  double? get _latitude {
    final raw = widget.registryData['latitude'];
    if (raw is double) return raw;
    if (raw is num) return raw.toDouble();
    return null;
  }

  double? get _longitude {
    final raw = widget.registryData['longitude'];
    if (raw is double) return raw;
    if (raw is num) return raw.toDouble();
    return null;
  }

  LatLng? get _latLng =>
      (_latitude != null && _longitude != null)
          ? LatLng(_latitude!, _longitude!)
          : null;

  Future<void> _joinLibrary() async {
    setState(() => _isJoining = true);
    final error = await ref.read(authProvider.notifier).joinLibrary(
          ownerUid: _ownerUid,
          libraryId: _libraryId,
          libraryName: _libraryName,
          phone: _contactNumber.isNotEmpty ? _contactNumber : null,
          address: _address.isNotEmpty ? _address : null,
        );
    if (!mounted) return;
    setState(() => _isJoining = false);

    if (error == null) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Request Sent'),
          content: const Text(
              'Waiting for owner approval. You will get full access once they approve.'),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                Navigator.pop(ctx);
                context.go('/dashboard');
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

  Future<void> _openInMaps() async {
    final ll = _latLng;
    final uri = ll != null
        ? Uri.parse('https://www.google.com/maps?q=${ll.latitude},${ll.longitude}')
        : Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('$_libraryName $_address')}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasMap = _latLng != null;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.floatingBar,
        middle: const Text('Library Details'),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  GlassContainer(
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.systemBlue,
                                AppColors.systemPurple,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            CupertinoIcons.building_2_fill,
                            color: CupertinoColors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _libraryName,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.label,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              if (_address.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _address,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.secondaryLabel,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  GlassContainer(
                    child: Column(
                      children: [
                        if (_contactNumber.isNotEmpty) ...[
                          _infoRow(
                            CupertinoIcons.phone_fill,
                            'Contact',
                            _contactNumber,
                            AppColors.success,
                            onTap: () async {
                              final uri = Uri.parse('tel:$_contactNumber');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (_address.isNotEmpty) ...[
                          _infoRow(
                            CupertinoIcons.location_solid,
                            'Address',
                            _address,
                            AppColors.systemBlue,
                          ),
                          const SizedBox(height: 12),
                        ],
                        _infoRow(
                          CupertinoIcons.rectangle_grid_1x2_fill,
                          'Seat Capacity',
                          _seatCapacity > 0
                              ? (_availableSeats > 0 && _availableSeats < _seatCapacity
                                  ? '$_availableSeats of $_seatCapacity available'
                                  : '$_seatCapacity seats')
                              : 'Not specified',
                          AppColors.systemCyan,
                        ),
                        if (_facilities.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _infoRow(
                            CupertinoIcons.hammer,
                            'Facilities',
                            _facilities.join(' • '),
                            AppColors.systemOrange,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (hasMap) ...[
                    const SizedBox(height: 12),
                    GlassContainer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                CupertinoIcons.map_pin_ellipse,
                                color: AppColors.systemBlue,
                                size: 17,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Location',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.label,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              height: 180,
                              child: FlutterMap(
                                options: MapOptions(
                                  initialCenter: _latLng!,
                                  initialZoom: 15,
                                  interactionOptions: const InteractionOptions(
                                    flags: InteractiveFlag.none,
                                  ),
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate:
                                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName:
                                        'com.librarymanager.student',
                                  ),
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        point: _latLng!,
                                        width: 30,
                                        height: 30,
                                        child: const Icon(
                                          CupertinoIcons.location_fill,
                                          color: AppColors.systemBlue,
                                          size: 30,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: _openInMaps,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.systemBlue
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      CupertinoIcons.map_fill,
                                      color: AppColors.systemBlue,
                                      size: 16,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Open in Maps',
                                      style: TextStyle(
                                        color: AppColors.systemBlue,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Sticky Join button
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: BoxDecoration(
                color: AppColors.secondarySystemGroupedBackground,
                border: const Border(
                  top: BorderSide(color: AppColors.separator, width: 0.5),
                ),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    borderRadius: BorderRadius.circular(14),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    onPressed: _isJoining ? null : _joinLibrary,
                    child: _isJoining
                        ? const CupertinoActivityIndicator(
                            color: CupertinoColors.white)
                        : const Text(
                            'Join This Library',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: CupertinoColors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value,
    Color color, {
    VoidCallback? onTap,
  }) {
    final content = Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: color, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.tertiaryLabel,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.label,
                ),
              ),
            ],
          ),
        ),
        if (onTap != null)
          const Icon(
            CupertinoIcons.chevron_right,
            color: AppColors.tertiaryLabel,
            size: 16,
          ),
      ],
    );

    return onTap != null
        ? GestureDetector(onTap: onTap, child: content)
        : content;
  }
}
