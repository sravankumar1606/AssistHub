import 'package:geolocator/geolocator.dart';

/// Thin wrapper around `geolocator` for permission handling and
/// getting/streaming the device's current position.
class LocationService {
  /// Ensures location services are on and permission is granted.
  /// Returns false if the user can't be tracked (denied, disabled, etc.).
  Future<bool> ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  Future<Position?> getCurrentPosition() async {
    final hasPermission = await ensurePermission();
    if (!hasPermission) return null;
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  /// Stream of position updates, fired roughly every [distanceFilterMeters]
  /// of movement. Use this to continuously broadcast an employee's location
  /// while a booking is active.
  Stream<Position> positionStream({int distanceFilterMeters = 15}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterMeters,
      ),
    );
  }

  double distanceInMeters({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }
}