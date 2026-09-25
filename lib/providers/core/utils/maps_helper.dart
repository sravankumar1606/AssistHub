import 'package:url_launcher/url_launcher.dart';

/// Opens Google Maps at a given address or coordinates using Google's
/// free "Universal Maps URL" scheme — no Maps API key, no billing
/// account required. Opens the Google Maps app on mobile, or
/// maps.google.com in a browser tab on web/desktop.
class MapsHelper {
  static Future<bool> openAddress(String address) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}',
    );
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<bool> openCoordinates(double latitude, double longitude) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Opens turn-by-turn directions to an address, from the user's
  /// current location (Google Maps asks for location permission itself).
  static Future<bool> openDirections(String destinationAddress) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(destinationAddress)}',
    );
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
