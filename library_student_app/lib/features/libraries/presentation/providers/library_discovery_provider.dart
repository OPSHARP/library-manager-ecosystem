import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../data/models/nearby_library.dart';
import '../../data/repositories/library_discovery_repository.dart';

final libraryDiscoveryRepositoryProvider =
    Provider<LibraryDiscoveryRepository>((ref) => LibraryDiscoveryRepository());

class LibraryDiscoveryState {
  final bool isLoading;
  final String? error;
  final LatLng? userLocation;
  final List<NearbyLibrary> libraries;

  const LibraryDiscoveryState({
    this.isLoading = true,
    this.error,
    this.userLocation,
    this.libraries = const [],
  });

  LibraryDiscoveryState copyWith({
    bool? isLoading,
    String? error,
    LatLng? userLocation,
    List<NearbyLibrary>? libraries,
  }) {
    return LibraryDiscoveryState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      userLocation: userLocation ?? this.userLocation,
      libraries: libraries ?? this.libraries,
    );
  }
}

class LibraryDiscoveryNotifier extends StateNotifier<LibraryDiscoveryState> {
  final LibraryDiscoveryRepository _repo;

  LibraryDiscoveryNotifier(this._repo)
      : super(const LibraryDiscoveryState()) {
    load();
  }

  Future<void> load() async {
    state = const LibraryDiscoveryState(isLoading: true);
    try {
      final position = await _repo.getCurrentPosition();
      final userLoc = position == null
          ? null
          : LatLng(position.latitude, position.longitude);

      var libraries = await _repo.fetchLibraries();

      for (var i = 0; i < libraries.length; i++) {
        final lib = libraries[i];
        LatLng? coords;
        if (lib.latitude == null || lib.longitude == null) {
          coords = await _repo.geocode('${lib.libraryName}, ${lib.address}');
        } else {
          coords = lib.latLng;
        }
        double? distance;
        if (coords != null && userLoc != null) {
          distance = NearbyLibrary.distanceBetween(userLoc, coords);
        }
        libraries[i] = lib.copyWith(
          latitude: coords?.latitude,
          longitude: coords?.longitude,
          distanceKm: distance,
        );
      }

      // Nearest first; libraries without coordinates go last.
      libraries.sort((a, b) {
        if (a.distanceKm == null && b.distanceKm == null) return 0;
        if (a.distanceKm == null) return 1;
        if (b.distanceKm == null) return -1;
        return a.distanceKm!.compareTo(b.distanceKm!);
      });

      state = LibraryDiscoveryState(
        isLoading: false,
        userLocation: userLoc,
        libraries: libraries,
      );
    } catch (e) {
      state = LibraryDiscoveryState(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() => load();
}

final libraryDiscoveryProvider = StateNotifierProvider<LibraryDiscoveryNotifier, LibraryDiscoveryState>(
  (ref) {
    final repo = ref.watch(libraryDiscoveryRepositoryProvider);
    return LibraryDiscoveryNotifier(repo);
  },
);
