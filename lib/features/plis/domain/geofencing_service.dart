import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:pli_runner/core/models/pli.dart';

class GeofencingService {
  StreamSubscription<Position>? _positionSubscription;
  final double _radiusMeters;
  final void Function(Pli pli, double distanceMeters)? onApproaching;

  List<Pli> _watchedPlis = [];

  GeofencingService({
    double radiusMeters = 500,
    this.onApproaching,
  }) : _radiusMeters = radiusMeters;

  void updateWatchedPlis(List<Pli> plis) {
    _watchedPlis = plis.where((p) => p.hasCoordinates && p.status == PliStatus.pending).toList();
  }

  Future<bool> requestPermissions() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;

    // Request "always" for background tracking
    if (permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
    }

    return true;
  }

  Future<void> startTracking() async {
    await _positionSubscription?.cancel();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 100, // Update every 100m
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(_onPositionUpdate);
  }

  void _onPositionUpdate(Position position) {
    for (final pli in _watchedPlis) {
      if (!pli.hasCoordinates) continue;

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        pli.latitude!,
        pli.longitude!,
      );

      if (distance <= _radiusMeters) {
        onApproaching?.call(pli, distance);
      }
    }
  }

  Future<Position?> getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } catch (e) {
      return null;
    }
  }

  void stop() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }
}
