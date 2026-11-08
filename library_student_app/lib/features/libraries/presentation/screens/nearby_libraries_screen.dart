import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../data/models/nearby_library.dart';
import '../providers/library_discovery_provider.dart';

/// Shows libraries registered in the Library Manager & Owner app on an
/// OpenStreetMap map plus a nearest-first list (uses the device location and
/// OSM geocoding).
class NearbyLibrariesScreen extends ConsumerWidget {
  const NearbyLibrariesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(libraryDiscoveryProvider);

    return CupertinoPageScaffold(
      backgroundColor: AppColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.floatingBar,
        middle: const Text('Nearby Libraries'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => ref.read(libraryDiscoveryProvider.notifier).refresh(),
          child: const Icon(CupertinoIcons.refresh),
        ),
      ),
      child: SafeArea(
        child: state.isLoading
            ? const LoadingWidget(message: 'Finding libraries near you…')
            : state.error != null
                ? _buildError(context, state.error!, ref)
                : state.libraries.isEmpty
                    ? _buildEmpty(ref)
                    : _buildContent(state),
      ),
    );
  }

  Widget _buildError(BuildContext context, String error, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.cloud_download,
              size: 56,
              color: AppColors.tertiaryLabel,
            ),
            const SizedBox(height: 16),
            Text(
              error,
              style: const TextStyle(
                color: AppColors.secondaryLabel,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            CupertinoButton.filled(
              borderRadius: BorderRadius.circular(12),
              onPressed: () =>
                  ref.read(libraryDiscoveryProvider.notifier).refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.building_2_fill,
              size: 56,
              color: AppColors.tertiaryLabel,
            ),
            const SizedBox(height: 16),
            const Text(
              'No libraries registered yet.\nAsk a library owner to register their library in the Library Manager & Owner app.',
              style: TextStyle(
                color: AppColors.secondaryLabel,
                fontSize: 14,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            CupertinoButton.filled(
              borderRadius: BorderRadius.circular(12),
              onPressed: () =>
                  ref.read(libraryDiscoveryProvider.notifier).refresh(),
              child: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(LibraryDiscoveryState state) {
    final located = state.libraries.where((l) => l.latLng != null).toList();
    final center = state.userLocation ??
        (located.isNotEmpty ? located.first.latLng! : const LatLng(28.6139, 77.2090));
    final zoom = state.userLocation != null ? 13.0 : 6.0;

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: zoom,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.librarymanager.student',
              ),
              if (state.userLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: state.userLocation!,
                      width: 24,
                      height: 24,
                      child: const Icon(
                        CupertinoIcons.location_fill,
                        color: AppColors.systemBlue,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: located.map((l) {
                  final isNearest = l == located.first;
                  return Marker(
                    point: l.latLng!,
                    width: isNearest ? 120 : 30,
                    height: isNearest ? 50 : 30,
                    child: isNearest
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.success,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  l.distanceKm != null
                                      ? '${l.distanceKm!.toStringAsFixed(1)} km'
                                      : 'Nearest',
                                  style: const TextStyle(
                                    color: CupertinoColors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Icon(
                                CupertinoIcons.book_fill,
                                color: AppColors.success,
                                size: 30,
                              ),
                            ],
                          )
                        : const Icon(
                            CupertinoIcons.book_fill,
                            color: AppColors.systemPurple,
                            size: 30,
                          ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            itemCount: state.libraries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) =>
                _LibraryTile(library: state.libraries[index]),
          ),
        ),
      ],
    );
  }
}

class _LibraryTile extends StatelessWidget {
  final NearbyLibrary library;

  const _LibraryTile({required this.library});

  void _openPreview(BuildContext context) {
    final registryData = {
      'ownerUid': library.ownerUid,
      'libraryId': library.libraryId,
      'libraryName': library.libraryName,
      'address': library.address,
      'contactNumber': library.contactNumber,
      'seatCapacity': library.totalSeats,
      'latitude': library.latitude,
      'longitude': library.longitude,
    };
    context.push('/library-preview', extra: registryData);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openPreview(context),
      behavior: HitTestBehavior.opaque,
      child: GlassContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.systemBlue, AppColors.systemPurple],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    CupertinoIcons.building_2_fill,
                    color: CupertinoColors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    library.libraryName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.label,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.systemBlue.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    library.distanceDisplay,
                    style: const TextStyle(
                      color: AppColors.systemBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (library.address.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    CupertinoIcons.location_solid,
                    size: 14,
                    color: AppColors.secondaryLabel,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      library.address,
                      style: const TextStyle(
                        color: AppColors.secondaryLabel,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (library.contactNumber.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    CupertinoIcons.phone_fill,
                    size: 14,
                    color: AppColors.secondaryLabel,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    library.contactNumber,
                    style: const TextStyle(
                      color: AppColors.secondaryLabel,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.infoBg,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    '${library.totalSeats} total seats',
                    style: const TextStyle(
                      color: AppColors.systemBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                const Icon(
                  CupertinoIcons.arrow_up_right_circle,
                  size: 16,
                  color: AppColors.tertiaryLabel,
                ),
                const SizedBox(width: 4),
                const Text(
                  'Open in Map',
                  style: TextStyle(
                    color: AppColors.tertiaryLabel,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
