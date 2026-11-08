import 'dart:convert';

import 'package:http/http.dart' as http;

/// Lightweight OpenStreetMap Nominatim geocoding helpers used by the owner
/// app to turn a picked device position into an address (and vice-versa)
/// before publishing the library's location to all students.
class GeocodeService {
  static const String _userAgent = 'LibraryManagerOwner/1.0';

  /// Resolves [address] to [latitude, longitude]. Returns null when the
  /// address cannot be resolved or the request fails.
  static Future<List<double>?> geocode(String address) async {
    if (address.trim().isEmpty) return null;
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/search')
          .replace(queryParameters: {
        'q': address.trim(),
        'format': 'json',
        'limit': '1',
      });
      final res = await http.get(uri, headers: const {'User-Agent': _userAgent});
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as List;
      if (data.isEmpty) return null;
      final lat = double.tryParse(data[0]['lat']?.toString() ?? '');
      final lon = double.tryParse(data[0]['lon']?.toString() ?? '');
      if (lat == null || lon == null) return null;
      return [lat, lon];
    } catch (_) {
      return null;
    }
  }

  /// Reverse-geocodes [latitude]/[longitude] into a human readable address.
  /// Returns null when the lookup fails.
  static Future<String?> reverseGeocode(double latitude, double longitude) async {
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse')
          .replace(queryParameters: {
        'lat': latitude.toStringAsFixed(6),
        'lon': longitude.toStringAsFixed(6),
        'format': 'jsonv2',
      });
      final res = await http.get(uri, headers: const {'User-Agent': _userAgent});
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final display = data['display_name'] as String?;
      if (display == null || display.isEmpty) return null;
      return display;
    } catch (_) {
      return null;
    }
  }
}
