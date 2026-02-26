import 'package:geocoding/geocoding.dart' as geo;

class GeocodingResult {
  final double latitude;
  final double longitude;
  final String? formattedAddress;

  const GeocodingResult({
    required this.latitude,
    required this.longitude,
    this.formattedAddress,
  });
}

class GeocodingService {
  /// Convert an address string to GPS coordinates
  Future<GeocodingResult?> geocodeAddress(String address) async {
    try {
      final locations = await geo.locationFromAddress(address);
      if (locations.isEmpty) return null;

      final location = locations.first;

      // Reverse geocode to get a clean formatted address
      final placemarks = await geo.placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );

      String? formatted;
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        formatted = [p.street, p.postalCode, p.locality]
            .where((s) => s != null && s.isNotEmpty)
            .join(', ');
      }

      return GeocodingResult(
        latitude: location.latitude,
        longitude: location.longitude,
        formattedAddress: formatted,
      );
    } catch (e) {
      return null;
    }
  }
}
