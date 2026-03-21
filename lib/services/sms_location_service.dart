import 'package:geolocator/geolocator.dart';
import 'package:telephony/telephony.dart';

class LocationService {
  static final _geolocator = Geolocator();

  /// Request location permissions
  static Future<bool> requestLocationPermission() async {
    final permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      final result = await Geolocator.requestPermission();
      return result == LocationPermission.whileInUse ||
          result == LocationPermission.always;
    }

    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  /// Get current location with high accuracy
  static Future<Position?> getCurrentLocation() async {
    try {
      final hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        print('Location permission denied');
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      print('Location obtained: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  /// Format location as a string
  static String formatLocation(Position position) {
    return '${position.latitude},${position.longitude}';
  }

  /// Generate a location URL for sharing
  static String getLocationUrl(Position position) {
    return 'https://maps.google.com/?q=${position.latitude},${position.longitude}';
  }
}

class SMSService {
  static final Telephony telephony = Telephony.instance;

  /// Request SMS permission
  static Future<bool> requestSmsPermission() async {
    try {
      final permissionGranted =
          await telephony.requestSmsPermissions ?? false;
      return permissionGranted;
    } catch (e) {
      print('Error requesting SMS permission: $e');
      return false;
    }
  }

  /// Send SOS SMS to emergency contact
  static Future<bool> sendSOSMessage(
    String phoneNumber,
    String location,
  ) async {
    try {
      final hasPermission = await requestSmsPermission();
      if (!hasPermission) {
        print('SMS permission denied');
        return false;
      }

      final message =
          'SOS ALERT: Fall detected! Location: $location. Contact emergency services.';

      await telephony.sendSmsByDefaultApp(
        to: phoneNumber,
        message: message,
      );

      print('SOS message sent to $phoneNumber');
      return true;
    } catch (e) {
      print('Error sending SMS: $e');
      return false;
    }
  }

  /// Send detailed SOS with location link
  static Future<bool> sendSOSWithLocation(
    String phoneNumber,
    Position location,
  ) async {
    try {
      final hasPermission = await requestSmsPermission();
      if (!hasPermission) {
        print('SMS permission denied');
        return false;
      }

      final locationUrl = LocationService.getLocationUrl(location);
      final message =
          'EMERGENCY: Fall detected! Location: $locationUrl Coordinates: ${location.latitude}, ${location.longitude}';

      await telephony.sendSmsByDefaultApp(
        to: phoneNumber,
        message: message,
      );

      print('Detailed SOS sent to $phoneNumber with location');
      return true;
    } catch (e) {
      print('Error sending detailed SOS: $e');
      return false;
    }
  }
}
