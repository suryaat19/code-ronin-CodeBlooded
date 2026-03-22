import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationService {
  /// Request location permissions and ensure location services are enabled
  static Future<bool> requestLocationPermission() async {
    // First check if location services are enabled at all
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('[WARNING] Location services are DISABLED - asking user to enable');
      // Open location settings so user can enable GPS
      await Geolocator.openLocationSettings();
      // Re-check after user returns
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('[ERROR] Location services still disabled');
        return false;
      }
    }

    // Check & request permission
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('[ERROR] Location permission denied by user');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('[ERROR] Location permission permanently denied - open app settings');
      await Geolocator.openAppSettings();
      return false;
    }

    return true;
  }

  /// Get current location with proper error handling
  static Future<Position?> getCurrentLocation() async {
    try {
      final hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        print('[ERROR] Cannot get location - permission denied');
        return null;
      }

      // Try to get last known position first (instant, no GPS wait)
      Position? lastKnown = await Geolocator.getLastKnownPosition();
      
      // Then get accurate current position
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 15),
        );

        print('[LOCATION] Obtained: ${position.latitude}, ${position.longitude}');
        return position;
      } catch (e) {
        print('[WARNING] getCurrentPosition failed: $e');
        
        // Fall back to last known position if current fetch fails
        if (lastKnown != null) {
          print('[LOCATION] Using last known: ${lastKnown.latitude}, ${lastKnown.longitude}');
          return lastKnown;
        }
        
        return null;
      }
    } catch (e) {
      print('[ERROR] Getting location: $e');
      return null;
    }
  }

  /// Generate a location URL for sharing
  static String getLocationUrl(Position position) {
    return 'https://maps.google.com/?q=${position.latitude},${position.longitude}';
  }
}

class SMSService {
  /// Send SOS SMS to emergency contact
  static Future<bool> sendSOSMessage(
    String phoneNumber,
    String location,
  ) async {
    final message =
        'SOS ALERT: Fall detected!\n\n'
        'Location: $location\n\n'
        'Please contact emergency services immediately.';

    return await _sendSms(phoneNumber, message);
  }

  /// Send detailed SOS with location link
  static Future<bool> sendSOSWithLocation(
    String phoneNumber,
    Position location,
  ) async {
    final locationUrl = LocationService.getLocationUrl(location);
    final message =
        'EMERGENCY SOS: Fall detected!\n\n'
        'Location: $locationUrl\n'
        'Coordinates: ${location.latitude}, ${location.longitude}\n\n'
        'Please send help immediately!';

    return await _sendSms(phoneNumber, message);
  }

  /// Send SMS via url_launcher (opens SMS app with pre-filled message)
  static Future<bool> _sendSms(String phoneNumber, String message) async {
    try {
      final uri = Uri(
        scheme: 'sms',
        path: phoneNumber,
        queryParameters: {'body': message},
      );

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        print('[SMS] App opened for $phoneNumber');
        return true;
      }

      print('[ERROR] Could not launch SMS for $phoneNumber');
      return false;
    } catch (e) {
      print('[ERROR] SMS error: $e');
      return false;
    }
  }
}
