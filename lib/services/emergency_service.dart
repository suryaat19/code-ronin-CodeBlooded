import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:telephony/telephony.dart';

class EmergencyService {
  static final Telephony _telephony = Telephony.instance;
  static bool _locationPermissionRequested = false;

  /// Initialize emergency service (request permissions)
  static Future<void> initialize() async {
    await _requestLocationPermission();
    print('📱 Emergency Service initialized');
  }

  /// Request location permission
  static Future<void> _requestLocationPermission() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
      print('📍 Location permission requested');
    }
    _locationPermissionRequested = true;
  }

  /// Get current GPS location
  static Future<Position?> getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        print('❌ Location permission denied');
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      print(
          '✅ Location obtained: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      print('❌ Error getting location: $e');
      return null;
    }
  }

  /// Make emergency call to contact
  static Future<bool> makeEmergencyCall(String phoneNumber) async {
    try {
      // Validate phone number format
      if (phoneNumber.isEmpty) {
        print('❌ Invalid phone number');
        return false;
      }

      // Clean phone number (remove spaces, dashes)
      final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

      print('📞 Initiating emergency call to: $cleanNumber');

      // Make the call
      await _telephony.dialPhoneNumber(cleanNumber);
      // dialPhoneNumber returns void, assume success if no exception
      print('✅ Emergency call initiated to $cleanNumber');
      return true;
    } catch (e) {
      print('❌ Error making emergency call: $e');
      return false;
    }
  }

  /// Send emergency SMS with location
  static Future<bool> sendEmergencySMS({
    required String phoneNumber,
    required String message,
    Position? location,
  }) async {
    try {
      if (phoneNumber.isEmpty) {
        print('❌ Invalid phone number for SMS');
        return false;
      }

      // Build message with location if available
      String fullMessage = message;
      if (location != null) {
        final googleMapsUrl =
            'https://maps.google.com/?q=${location.latitude},${location.longitude}';
        fullMessage +=
            '\n\n📍 Location: ${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}\n🔗 $googleMapsUrl';
      }

      final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

      print('📨 Sending emergency SMS to: $cleanNumber');
      print('Message: $fullMessage');

      // Use sendSms method from telephony 0.2.0
      _telephony.sendSms(
        to: cleanNumber,
        message: fullMessage,
      );

      print('✅ Emergency SMS sent to $cleanNumber');
      return true;
    } catch (e) {
      print('❌ Error sending emergency SMS: $e');
      return false;
    }
  }

  /// Trigger complete emergency response (Call + SMS + Location)
  static Future<void> triggerEmergencyResponse({
    required String phoneNumber,
    required String contactName,
  }) async {
    try {
      print('\n🚨 === EMERGENCY RESPONSE TRIGGERED === 🚨');
      print('Contact: $contactName ($phoneNumber)\n');

      // Get location first
      final location = await getCurrentLocation();

      // Send SMS with location
      await sendEmergencySMS(
        phoneNumber: phoneNumber,
        message:
            '🆘 FALL DETECTED - I need help! This is an automated alert from FallSense.',
        location: location,
      );

      // Make emergency call
      await Future.delayed(const Duration(seconds: 1));
      await makeEmergencyCall(phoneNumber);

      print('\n✅ Emergency response completed');
    } catch (e) {
      print('❌ Error in emergency response: $e');
    }
  }

  /// Batch send to multiple contacts
  static Future<void> sendToMultipleContacts({
    required List<String> phoneNumbers,
    required List<String> contactNames,
  }) async {
    try {
      if (phoneNumbers.isEmpty) {
        print('❌ No emergency contacts available');
        return;
      }

      print('\n📢 Sending emergency alerts to ${phoneNumbers.length} contacts...\n');

      // Get location once
      final location = await getCurrentLocation();

      // Send to all contacts
      for (int i = 0; i < phoneNumbers.length; i++) {
        print('📨 Contact ${i + 1}/${phoneNumbers.length}');
        await sendEmergencySMS(
          phoneNumber: phoneNumbers[i],
          message:
              '🆘 FALL DETECTED - I need help! This is an automated alert from FallSense.',
          location: location,
        );

        // Add delay between SMS to avoid rate limiting
        if (i < phoneNumbers.length - 1) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      // Make call to first contact
      await Future.delayed(const Duration(seconds: 2));
      print('\n📞 Calling primary contact...');
      await makeEmergencyCall(phoneNumbers[0]);

      print('\n✅ All emergency alerts sent');
    } catch (e) {
      print('❌ Error in batch emergency sending: $e');
    }
  }
}
