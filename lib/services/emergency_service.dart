import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyService {
  static bool _locationPermissionRequested = false;

  /// Initialize emergency service (request permissions)
  static Future<void> initialize() async {
    await _requestLocationPermission();
    print('[EmergencyService] Initialized');
  }

  /// Request location permission
  static Future<void> _requestLocationPermission() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
      print('[EmergencyService] Location permission requested');
    }
    _locationPermissionRequested = true;
  }

  /// Get current GPS location
  static Future<Position?> getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        print('[EmergencyService] Location permission denied');
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      print('[EmergencyService] Location: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      print('[EmergencyService] Error getting location: $e');
      return null;
    }
  }

  /// Make emergency call to contact via url_launcher
  static Future<bool> makeEmergencyCall(String phoneNumber) async {
    try {
      if (phoneNumber.isEmpty) {
        print('[EmergencyService] Invalid phone number');
        return false;
      }

      final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      final uri = Uri(scheme: 'tel', path: cleanNumber);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        print('[EmergencyService] Call initiated to $cleanNumber');
        return true;
      }
      print('[EmergencyService] Could not launch call');
      return false;
    } catch (e) {
      print('[EmergencyService] Error making call: $e');
      return false;
    }
  }

  /// Send emergency SMS with location via url_launcher
  static Future<bool> sendEmergencySMS({
    required String phoneNumber,
    required String message,
    Position? location,
  }) async {
    try {
      if (phoneNumber.isEmpty) {
        print('[EmergencyService] Invalid phone number for SMS');
        return false;
      }

      String fullMessage = message;
      if (location != null) {
        final googleMapsUrl =
            'https://maps.google.com/?q=${location.latitude},${location.longitude}';
        fullMessage +=
            '\n\nLocation: ${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}\n$googleMapsUrl';
      }

      final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      final uri = Uri(
        scheme: 'sms',
        path: cleanNumber,
        queryParameters: {'body': fullMessage},
      );

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        print('[EmergencyService] SMS opened for $cleanNumber');
        return true;
      }

      print('[EmergencyService] Could not launch SMS');
      return false;
    } catch (e) {
      print('[EmergencyService] Error sending SMS: $e');
      return false;
    }
  }

  /// Trigger complete emergency response (Call + SMS + Location)
  static Future<void> triggerEmergencyResponse({
    required String phoneNumber,
    required String contactName,
  }) async {
    try {
      print('\n=== EMERGENCY RESPONSE TRIGGERED ===');
      print('Contact: $contactName ($phoneNumber)\n');

      final location = await getCurrentLocation();

      await sendEmergencySMS(
        phoneNumber: phoneNumber,
        message:
            'FALL DETECTED - I need help! This is an automated alert from FallSense.',
        location: location,
      );

      await Future.delayed(const Duration(seconds: 1));
      await makeEmergencyCall(phoneNumber);

      print('\nEmergency response completed');
    } catch (e) {
      print('[EmergencyService] Error in emergency response: $e');
    }
  }

  /// Batch send to multiple contacts
  static Future<void> sendToMultipleContacts({
    required List<String> phoneNumbers,
    required List<String> contactNames,
  }) async {
    try {
      if (phoneNumbers.isEmpty) {
        print('[EmergencyService] No emergency contacts available');
        return;
      }

      print('\nSending emergency alerts to ${phoneNumbers.length} contacts...\n');

      final location = await getCurrentLocation();

      for (int i = 0; i < phoneNumbers.length; i++) {
        print('Contact ${i + 1}/${phoneNumbers.length}');
        await sendEmergencySMS(
          phoneNumber: phoneNumbers[i],
          message:
              'FALL DETECTED - I need help! This is an automated alert from FallSense.',
          location: location,
        );

        if (i < phoneNumbers.length - 1) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      await Future.delayed(const Duration(seconds: 2));
      print('\nCalling primary contact...');
      await makeEmergencyCall(phoneNumbers[0]);

      print('\nAll emergency alerts sent');
    } catch (e) {
      print('[EmergencyService] Error in batch sending: $e');
    }
  }
}
