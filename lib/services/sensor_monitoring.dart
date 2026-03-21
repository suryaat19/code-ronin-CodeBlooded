import 'package:sensors_plus/sensors_plus.dart';
import 'dart:math';
import 'dart:async';

class SensorMonitoring {
  // ====== Enhanced Thresholds (tuned for better accuracy) ======
  static const double ACC_THRESHOLD = 22.0; // Accelerometer threshold (m/s²)
  static const double GYRO_THRESHOLD = 4.0; // Gyroscope threshold (rad/s)
  static const int COOLDOWN_SEC = 5; // Cooldown between detections
  static const double GRAVITY = 9.81; // m/s²

  // ====== State ======
  static double _accMag = 0;
  static double _gyroMag = 0;
  static DateTime? _lastTrigger;
  static bool _waitingForInactivity = false;
  static DateTime? _impactTime;

  // ====== Smoothing buffers ======
  static List<double> _accBuffer = [];
  static List<double> _gyroBuffer = [];
  static const int BUFFER_SIZE = 100; // Approximately 2 seconds at 50Hz
  static const int SMOOTH_WINDOW = 5; // Smoothing window size

  static StreamSubscription? _accelerometerSubscription;
  static StreamSubscription? _gyroscopeSubscription;

  /// Start monitoring sensors for fall detection
  static void startMonitoring({
    required Function(bool) onFallDetected,
  }) {
    try {
      // Listen to accelerometer
      _accelerometerSubscription = accelerometerEvents.listen(
        (AccelerometerEvent event) {
          _processSensorData(event, onFallDetected);
        },
        onError: (error) {
          print('Accelerometer error: $error');
        },
      );

      // Listen to gyroscope for additional context
      _gyroscopeSubscription = gyroscopeEvents.listen(
        (GyroscopeEvent event) {
          _processGyroData(event);
        },
        onError: (error) {
          print('Gyroscope error: $error');
        },
      );

      print('Advanced sensor monitoring started');
    } catch (e) {
      print('Error starting sensor monitoring: $e');
      print('Note: Sensors may not be available on this platform');
    }
  }

  /// Smooth values using moving average
  static double _smooth(double value, List<double> buffer) {
    buffer.add(value);
    if (buffer.length > SMOOTH_WINDOW) buffer.removeAt(0);
    return buffer.reduce((a, b) => a + b) / buffer.length;
  }

  /// Process accelerometer data
  static void _processSensorData(
    AccelerometerEvent event,
    Function(bool) onFallDetected,
  ) {
    double rawAcc =
        sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    _accMag = _smooth(rawAcc, _accBuffer);

    _checkFall(onFallDetected);
  }

  /// Process gyroscope data
  static void _processGyroData(GyroscopeEvent event) {
    double rawGyro =
        sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    _gyroMag = _smooth(rawGyro, _gyroBuffer);
  }

  /// Main fall detection logic with two-stage confirmation
  static void _checkFall(Function(bool) onFallDetected) {
    final now = DateTime.now();

    // Apply cooldown
    if (_lastTrigger != null &&
        now.difference(_lastTrigger!).inSeconds < COOLDOWN_SEC) {
      return;
    }

    bool impact = _accMag > ACC_THRESHOLD;
    bool rotation = _gyroMag > GYRO_THRESHOLD;

    // Stage 1: Detect initial impact + rotation
    if (impact && rotation && !_waitingForInactivity) {
      _waitingForInactivity = true;
      _impactTime = now;
      print('📋 Impact detected, waiting for inactivity confirmation...');
    }

    // Stage 2: Check for inactivity after initial impact
    if (_waitingForInactivity && _impactTime != null) {
      final diff = now.difference(_impactTime!).inMilliseconds;

      // Wait 500-2000ms window for device to settle
      if (diff > 500 && diff < 2000) {
        // Check if device becomes still (gravity range: 8-12 m/s²)
        if (_accMag > 8 && _accMag < 12) {
          print('🚨 FALL CONFIRMED! Acc: $_accMag, Gyro: $_gyroMag');
          _lastTrigger = now;
          _waitingForInactivity = false;
          onFallDetected(true);
        }
      }

      // Reset if detection window expires
      if (diff >= 2000) {
        print('⏱️ Impact detection window expired, resetting...');
        _waitingForInactivity = false;
      }
    }
  }

  /// Stop monitoring sensors
  static void stopMonitoring() {
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    print('Sensor monitoring stopped');
  }

  /// Get current acceleration magnitude
  static double getCurrentAcceleration(AccelerometerEvent event) {
    final double magnitude = sqrt(
      (event.x * event.x) + (event.y * event.y) + (event.z * event.z),
    );
    return magnitude / GRAVITY;
  }
}
