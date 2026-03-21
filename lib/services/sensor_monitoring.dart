import 'package:sensors_plus/sensors_plus.dart';
import 'dart:math';
import 'dart:async';

class SensorMonitoring {
  // ====== Ultra-Conservative Thresholds ======
  static const double ACC_THRESHOLD = 32.0; // Only REAL impacts (was 22.0)
  static const double GYRO_THRESHOLD = 5.0; // Significant rotation (was 4.0)
  static const int COOLDOWN_SEC = 10; // Longer cooldown (was 5)
  static const double GRAVITY = 9.81; // m/s²

  // ====== State ======
  static double _accMag = 0;
  static double _gyroMag = 0;
  static DateTime? _lastTrigger;
  static bool _waitingForInactivity = false;
  static DateTime? _impactTime;
  static int _immobilityConfirmCount = 0; // Must confirm immobility multiple times

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

    // Stage 1: Detect initial impact + rotation - VERY STRICT
    if (impact && rotation && !_waitingForInactivity) {
      _waitingForInactivity = true;
      _impactTime = now;
      _immobilityConfirmCount = 0;
      print('📋 Impact detected, waiting for inactivity confirmation...');
    }

    // Stage 2: Check for prolonged inactivity after impact
    if (_waitingForInactivity && _impactTime != null) {
      final diff = now.difference(_impactTime!).inMilliseconds;

      // Only start checking immobility AFTER 1 second (1000ms) - filters out brief movements
      if (diff > 1200 && diff < 3500) {
        // Person lying still: ACC must be VERY LOW (< 11) AND GYRO must be almost zero (< 0.5)
        if (_accMag < 11 && _gyroMag < 0.5) {
          _immobilityConfirmCount++;
          print('✓ Immobile: $_immobilityConfirmCount/10 - Acc: ${_accMag.toStringAsFixed(2)}, Gyro: ${_gyroMag.toStringAsFixed(2)}');
          
          // Require 10 consecutive confirmations (person must stay still for 500ms+)
          if (_immobilityConfirmCount >= 10) {
            print('🚨 FALL CONFIRMED! Acc: $_accMag, Gyro: $_gyroMag');
            _lastTrigger = now;
            _waitingForInactivity = false;
            _immobilityConfirmCount = 0;
            onFallDetected(true);
          }
        } else {
          // Failed immobility check - reset counter
          _immobilityConfirmCount = 0;
        }
      }

      // Reset if detection window expires
      if (diff >= 3500) {
        print('⏱️ Impact detection window expired, resetting...');
        _waitingForInactivity = false;
        _immobilityConfirmCount = 0;
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
