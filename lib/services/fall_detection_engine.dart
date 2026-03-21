import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import 'sensor_monitoring.dart';
import 'ml_fall_detector.dart';
import 'sms_location_service.dart';

class FallDetectionEngine {
  final Function(bool) onFallDetected;
  late Timer _sosTimer;
  bool _fallConfirmed = false;
  List<String> _emergencyContacts = [];

  FallDetectionEngine({
    required this.onFallDetected,
  });

  /// Initialize the complete fall detection system
  void initialize({required String? emergencyContact}) {
    if (emergencyContact != null) {
      _emergencyContacts = [emergencyContact];
    }
    
    // Start sensor monitoring with callback
    SensorMonitoring.startMonitoring(
      onFallDetected: (detected) {
        if (detected) {
          _handlePotentialFall();
        }
      },
    );

    print('Fall Detection Engine initialized');
  }

  /// Handle when sensors detect a potential fall
  Future<void> _handlePotentialFall() async {
    if (_fallConfirmed) return; // Already processing

    print('Potential fall detected - initiating verification...');

    // Phase 2: ML Verification
    // In a real scenario, we'd pass the sensor buffer to the ML model
    final mockSensorWindow = List<double>.generate(100, (_) => 2.5 + ((_ % 10) * 0.1));
    
    final confidence = await _verifyWithML(mockSensorWindow);

    if (confidence > 0.7) {
      _fallConfirmed = true;
      _onFallConfirmed();
    } else {
      print('Fall not confirmed by ML verification');
    }
  }

  /// Run ML verification on sensor data
  Future<double> _verifyWithML(List<double> sensorWindow) async {
    return await MLFallDetector.verifyFall(sensorWindow);
  }

  /// Handle confirmed fall
  void _onFallConfirmed() {
    print('Fall confirmed! Triggering Pre-Alarm screen...');
    onFallDetected(true);
    _startSOSCountdown();
  }

  /// Start the 15-second SOS countdown
  void _startSOSCountdown() {
    _sosTimer = Timer(const Duration(seconds: 15), _sendSOS);
    print('SOS countdown started - 15 seconds');
  }

  /// Cancel the SOS alert
  void cancelSOS() {
    if (_sosTimer.isActive) {
      _sosTimer.cancel();
      _fallConfirmed = false;
      print('SOS alert cancelled');
    }
  }

  /// Send the actual SOS message
  Future<void> _sendSOS() async {
    if (_emergencyContacts.isEmpty) {
      print('No emergency contacts set - cannot send SOS');
      return;
    }

    // Get current location
    final position = await LocationService.getCurrentLocation();

    // Send SOS to all emergency contacts
    for (final contact in _emergencyContacts) {
      print('Sending SOS to $contact');
      
      if (position != null) {
        // Send SMS with location
        final success = await SMSService.sendSOSWithLocation(
          contact,
          position,
        );

        if (success) {
          print('SOS sent successfully to $contact');
        } else {
          print('Failed to send SOS to $contact');
        }
      } else {
        // Send without location
        final success = await SMSService.sendSOSMessage(
          contact,
          'Location unavailable',
        );

        if (success) {
          print('SOS sent to $contact (without location)');
        }
      }
    }

    _fallConfirmed = false;
  }

  /// Cleanup
  void dispose() {
    SensorMonitoring.stopMonitoring();
    cancelSOS();
    print('Fall Detection Engine disposed');
  }

  /// Update emergency contact
  void updateEmergencyContact(String contact) {
    _emergencyContacts = [contact];
    print('Emergency contact updated: $contact');
  }

  /// Add emergency contact
  void addEmergencyContact(String contact) {
    if (!_emergencyContacts.contains(contact)) {
      _emergencyContacts.add(contact);
      print('Emergency contact added: $contact');
    }
  }

  /// Remove emergency contact
  void removeEmergencyContact(String contact) {
    _emergencyContacts.remove(contact);
    print('Emergency contact removed: $contact');
  }
}
