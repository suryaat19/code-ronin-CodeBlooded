import 'dart:async';
import 'dart:math';
import 'sensor_monitoring.dart';
import 'ml_fall_detector.dart';
import 'sms_location_service.dart';
import 'emergency_service.dart';

class FallDetectionEngine {
  final Function(bool) onFallDetected;
  Timer? _sosTimer;
  bool _fallConfirmed = false;
  List<String> _emergencyContacts = [];
  Map<String, String> _contactNames = {};

  FallDetectionEngine({
    required this.onFallDetected,
  });

  /// Initialize the complete fall detection system
  void initialize({required String? emergencyContact}) {
    if (emergencyContact != null) {
      _emergencyContacts = [emergencyContact];
      _contactNames[emergencyContact] = 'Primary Contact';
    }

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
  /// Pipeline: Rule-based scoring -> ML verification -> Confirm
  Future<void> _handlePotentialFall() async {
    if (_fallConfirmed) return;

    print('[DETECT] Rule-based fall detected - running ML verification...');

    final features = _extractFeatures();

    if (features == null) {
      print('[ML] Not enough sensor data for ML verification, confirming by rule-based score');
      _fallConfirmed = true;
      _onFallConfirmed();
      return;
    }

    final confidence = await MLFallDetector.verifyFall(features);

    if (confidence >= MLFallDetector.threshold) {
      print('[ML CONFIRMED] Confidence: ${(confidence * 100).toStringAsFixed(1)}%');
      _fallConfirmed = true;
      _onFallConfirmed();
    } else {
      print('[ML REJECTED] Confidence too low: ${(confidence * 100).toStringAsFixed(1)}%');
      _fallConfirmed = false;
    }
  }

  /// Extract 12 features from the sensor sliding window
  /// Matches the trained model's feature order exactly:
  ///  0: acc_max,  1: acc_mean,  2: acc_std,  3: acc_min,
  ///  4: acc_range, 5: gyro_max, 6: gyro_mean, 7: gyro_std,
  ///  8: jerk_max, 9: jerk_mean, 10: jerk_std, 11: energy
  List<double>? _extractFeatures() {
    final accData = SensorMonitoring.accWindow;
    final gyroData = SensorMonitoring.gyroWindow;

    if (accData.length < 5 || gyroData.length < 5) return null;

    // === Accelerometer statistics ===
    final accMax = accData.reduce(max);
    final accMin = accData.reduce(min);
    final accMean = accData.reduce((a, b) => a + b) / accData.length;
    final accVariance = accData.map((v) => (v - accMean) * (v - accMean))
        .reduce((a, b) => a + b) / accData.length;
    final accStd = sqrt(accVariance);
    final accRange = accMax - accMin;

    // === Gyroscope statistics ===
    final gyroMax = gyroData.reduce(max);
    final gyroMean = gyroData.reduce((a, b) => a + b) / gyroData.length;
    final gyroVariance = gyroData.map((v) => (v - gyroMean) * (v - gyroMean))
        .reduce((a, b) => a + b) / gyroData.length;
    final gyroStd = sqrt(gyroVariance);

    // === Jerk (rate of change of acceleration) ===
    final jerkValues = <double>[];
    for (int i = 1; i < accData.length; i++) {
      jerkValues.add(accData[i] - accData[i - 1]);
    }
    double jerkMax = 0, jerkMean = 0, jerkStd = 0;
    if (jerkValues.isNotEmpty) {
      jerkMax = jerkValues.map((v) => v.abs()).reduce(max);
      jerkMean = jerkValues.reduce((a, b) => a + b) / jerkValues.length;
      final jerkVar = jerkValues.map((v) => (v - jerkMean) * (v - jerkMean))
          .reduce((a, b) => a + b) / jerkValues.length;
      jerkStd = sqrt(jerkVar);
    }

    // === Energy (sum of squared acceleration magnitudes) ===
    final energy = accData.map((v) => v * v).reduce((a, b) => a + b);

    return [
      accMax,     //  0: acc_max
      accMean,    //  1: acc_mean
      accStd,     //  2: acc_std
      accMin,     //  3: acc_min
      accRange,   //  4: acc_range
      gyroMax,    //  5: gyro_max
      gyroMean,   //  6: gyro_mean
      gyroStd,    //  7: gyro_std
      jerkMax,    //  8: jerk_max
      jerkMean,   //  9: jerk_mean
      jerkStd,    // 10: jerk_std
      energy,     // 11: energy
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

