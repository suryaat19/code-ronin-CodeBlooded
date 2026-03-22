import 'dart:async';
import 'sensor_monitoring.dart';
import 'ml_fall_detector.dart';
import 'sms_location_service.dart';
import 'emergency_service.dart';

class FallDetectionEngine {
  final Function(bool) onFallDetected;
  Timer? _sosTimer;
  bool _fallConfirmed = false;
  List<String> _emergencyContacts = [];
  Map<String, String> _contactNames = {}; // Map phone to contact name

  FallDetectionEngine({
    required this.onFallDetected,
  });

  /// Initialize the complete fall detection system
  void initialize({required String? emergencyContact}) {
    if (emergencyContact != null) {
      _emergencyContacts = [emergencyContact];
      _contactNames[emergencyContact] = 'Primary Contact';
    }

    // Start sensor monitoring - rule-based detection
    SensorMonitoring.startMonitoring(
      onFallDetected: (detected) {
        if (detected) {
          _handlePotentialFall();
        }
      },
    );

    print('Fall Detection Engine initialized (rule-based -> ML pipeline)');
  }

  /// Handle when sensors detect a potential fall
  /// Pipeline: Rule-based detection -> ML verification -> Confirm
  Future<void> _handlePotentialFall() async {
    if (_fallConfirmed) return; // Already processing

    print('[DETECT] Rule-based fall detected - running ML verification...');

    // Collect recent sensor data for ML verification
    // Use current readings as a simple feature vector
    final sensorWindow = _collectSensorWindow();

    // ML verification
    final confidence = await MLFallDetector.verifyFall(sensorWindow);

    print('[ML] Confidence: ${(confidence * 100).toStringAsFixed(1)}%');

    if (confidence >= 0.3) {
      // ML confirms the fall
      print('[ML CONFIRMED] Fall confirmed (confidence: ${(confidence * 100).toStringAsFixed(1)}%)');
      _fallConfirmed = true;
      _onFallConfirmed();
    } else {
      // ML says it's not a fall - reset
      print('[ML REJECTED] Fall rejected (confidence too low: ${(confidence * 100).toStringAsFixed(1)}%)');
      _fallConfirmed = false;
    }
  }

  /// Collect a simple sensor window for ML input
  List<double> _collectSensorWindow() {
    // Provide current sensor readings as features
    // In production, you'd buffer a 2-second window of raw data
    return [
      SensorMonitoring.currentAccMag,
      SensorMonitoring.currentRawAccMag,
      SensorMonitoring.currentGyroMag,
    ];
  }

  /// Handle confirmed fall
  void _onFallConfirmed() {
    print('[ALERT] Fall confirmed! Triggering Pre-Alarm screen...');
    onFallDetected(true);
    _startSOSCountdown();
  }

  /// Start the 15-second SOS countdown
  void _startSOSCountdown() {
    _sosTimer?.cancel();
    _sosTimer = Timer(const Duration(seconds: 15), _sendSOS);
    print('[SOS] Countdown started - 15 seconds');
  }

  /// Cancel the SOS alert
  void cancelSOS() {
    _sosTimer?.cancel();
    _fallConfirmed = false;
    print('[SOS] Alert cancelled');
  }

  /// Send the actual SOS message with emergency call to respective contacts
  Future<void> _sendSOS() async {
    if (_emergencyContacts.isEmpty) {
      print('[WARNING] No emergency contacts set - cannot send SOS');
      _fallConfirmed = false;
      return;
    }

    final position = await LocationService.getCurrentLocation();

    for (final contact in _emergencyContacts) {
      print('[SOS] Sending to $contact');

      if (position != null) {
        final success = await SMSService.sendSOSWithLocation(contact, position);
        print(success
            ? '[OK] SOS sent to $contact'
            : '[FAIL] Failed to send SOS to $contact');
      } else {
        final success = await SMSService.sendSOSMessage(
          contact,
          'Location unavailable',
        );
        print(success
            ? '[OK] SOS sent to $contact (without location)'
            : '[FAIL] Failed to send SOS to $contact');
      }
    }

    print('\n✅ Emergency SOS protocol completed');
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
  }

  /// Add emergency contact with name
  void addEmergencyContact(String contact, {String? contactName}) {
    if (!_emergencyContacts.contains(contact)) {
      _emergencyContacts.add(contact);
    }
  }

  /// Remove emergency contact
  void removeEmergencyContact(String contact) {
    _emergencyContacts.remove(contact);
  }
}

