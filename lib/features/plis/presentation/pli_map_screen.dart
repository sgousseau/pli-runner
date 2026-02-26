import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pli_runner/core/models/pli.dart';
import 'package:pli_runner/core/providers.dart';

class PliMapScreen extends ConsumerWidget {
  const PliMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plis = ref.watch(plisProvider);
    final geolocatedPlis = plis.where((p) => p.hasCoordinates).toList();

    final markers = geolocatedPlis.map((pli) {
      final hue = switch (pli.status) {
        PliStatus.pending => BitmapDescriptor.hueOrange,
        PliStatus.pickedUp => BitmapDescriptor.hueBlue,
        PliStatus.delivered => BitmapDescriptor.hueGreen,
        PliStatus.failed => BitmapDescriptor.hueRed,
      };

      return Marker(
        markerId: MarkerId(pli.id),
        position: LatLng(pli.latitude!, pli.longitude!),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        infoWindow: InfoWindow(
          title: '#${pli.clientNumber}',
          snippet: pli.address,
        ),
      );
    }).toSet();

    // Default to Paris center if no plis
    final initialPosition = geolocatedPlis.isNotEmpty
        ? LatLng(geolocatedPlis.first.latitude!, geolocatedPlis.first.longitude!)
        : const LatLng(48.8566, 2.3522);

    return Scaffold(
      appBar: AppBar(title: const Text('Carte des plis')),
      body: geolocatedPlis.isEmpty
          ? const Center(child: Text('Aucun pli géolocalisé'))
          : GoogleMap(
              initialCameraPosition: CameraPosition(target: initialPosition, zoom: 12),
              markers: markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
            ),
    );
  }
}
