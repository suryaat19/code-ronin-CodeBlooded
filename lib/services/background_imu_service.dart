import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Background IMU monitoring service
/// Runs in a separate isolate to continuously monitor accelerometer and gyroscope
/// Detects falls even when app is closed/minimized
class BackgroundIMUService {
  // Fall detection thresholds
  static const double accThreshold = 20.0;
  static const double gyroThreshold = 3.0;
  static const double minAcc = 12.0;
  static const double maxGyro = 12.0;
  static const int cooldownSec = 5;
  static const int stabilityThreshold = 5;

  // State variables for fall detection
  static double _accMag = 0;
  static double _gyroMag = 0;
  static double _zAxis = 0;
  static double _prevAccMag = 0;
  static DateTime? _lastTrigger;
  static bool _waitingForInactivity = false;
  static bool _validImpactDetected = false;
  static DateTime? _impactTime;
  static int _stableCount = 0;
  static final List<double> _accBuffer = [];
  static final List<double> _gyroBuffer = [];
  static late Timer _checkTimer;

  /// Initialize background IMU service
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    /// IMPORTANT: Foreground service configuration for Android
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        // Automatically start service when Android app process is killed
        autoStart: true,
        onStart: onStart,
        // High priority for more reliable background execution
        isForegroundMode: true,
        notificationChannelId: 'fallsense_bg_service',
        initialNotificationTitle: 'FallSense Monitoring',
        initialNotificationContent: 'Fall detection active in background',
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        // iOS doesn't require foreground service for sensor monitoring
        onBackground: onStart,
      ),
    );

    print('✅ Background IMU Service configured');
  }

  /// Main background service entry point
  @pragma('vm:entry-point')
  static Future<bool> onStart(ServiceInstance service) async {
    print('🔄 Background IMU Service started');

    // Keep wakelock to ensure continuous monitoring
    await WakelockPlus.enable();

    // Listen to accelerometer events
    final accStreamSubscription = accelerometerEvents.listen(
      (AccelerometerEvent event) {
        _processAccelerometerData(event);
      },
    );

    // Listen to gyroscope events
    final gyroStreamSubscription = gyroscopeEvents.listen(
      (GyroscopeEvent event) {
        _processGyroscopeData(event);
      },
    );

    // Periodic fall detection check
    _checkTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _checkFallBackground(service);
    });

    // Handle service stop
    if (service is AndroidServiceInstance) {
      service.on('stopService').listen((event) {
        accStreamSubscription.cancel();
        gyroStreamSubscription.cancel();
        _checkTimer.cancel();
        WakelockPlus.disable();
        service.stopSelf();
        print('🛑 Background IMU Service stopped');
      });
    }

    return true;
  }

  /// Process accelerometer data
  static void _processAccelerometerData(AccelerometerEvent event) {
    double rawAcc = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    _prevAccMag = _accMag;
    _accMag = _smooth(rawAcc, _accBuffer);
    _zAxis = event.z;
  }

  /// Process gyroscope data
  static void _processGyroscopeData(GyroscopeEvent event) {
    double rawGyro = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    _gyroMag = _smooth(rawGyro, _gyroBuffer);
  }

  /// Smoothing function using moving average
  static double _smooth(double value, List<double> buffer) {
    buffer.add(value);
    if (buffer.length > 5) buffer.removeAt(0);
    return buffer.reduce((a, b) => a + b) / buffer.length;
  }

  /// Background fall detection algorithm
  static void _checkFallBackground(ServiceInstance service) {
    final now = DateTime.now();

    // Safety check: acceleration must be in reasonable range
    if (_accMag < minAcc) return;

    // Cooldown check
    if (_lastTrigger != null &&
        now.difference(_lastTrigger!).inSeconds < cooldownSec) {
      return;
    }

    // Ignore extreme spin (likely phone throw)
    if (_gyroMag > maxGyro) {
      return;
    }

    // Acceleration slope detection
    double accSlope = _accMag - _prevAccMag;
    bool rapidDeceleration = accSlope < -5.0;

    // Orientation detection: Z-axis near 0 = device horizontal
    bool likelyHorizontal = _zAxis.abs() < 3.0;
    double adaptiveGyroThreshold = likelyHorizontal
        ? gyroThreshold * 0.8
        : gyroThreshold;

    bool impact =
        _accMag > accThreshold && (rapidDeceleration || _accMag > 22.0);
    bool rotation = _gyroMag > adaptiveGyroThreshold;

    // Step 1: Detect impact + rotation
    if (impact && rotation && !_waitingForInactivity) {
      _waitingForInactivity = true;
      _validImpactDetected = true;
      _impactTime = now;
      print(
          '⚡ BACKGROUND: Impact + Rotation detected - Acc: ${_accMag.toStringAsFixed(2)}, Gyro: ${_gyroMag.toStringAsFixed(2)}');
    }

    // Step 2: Check inactivity after impact
    if (_waitingForInactivity && _impactTime != null && _validImpactDetected) {
      final diff = now.difference(_impactTime!).inMilliseconds;

      // Progressive threshold: relax stability requirement as time passes
      double relaxedGravityMin = 9.5 + ((diff - 500) / 1500) * 0.3;
      double relaxedGravityMax = 10.8 + ((diff - 500) / 1500) * 0.3;

      if (diff > 500 && diff < 2000) {
        if (_accMag > relaxedGravityMin && _accMag < relaxedGravityMax) {
          _stableCount++;
          print(
              '🔍 BACKGROUND: Stability check: $_stableCount/6 - Acc: ${_accMag.toStringAsFixed(2)}');

          if (_stableCount > stabilityThreshold && _validImpactDetected) {
            print('✅ BACKGROUND: FALL CONFIRMED - Triggering PreAlarmScreen');
            _lastTrigger = now;
            _waitingForInactivity = false;
            _validImpactDetected = false;
            _stableCount = 0;

            // TRIGGER FALL DETECTION TO FOREGROUND
            _triggerFallDetectionUI(service);
          }
        } else {
          _stableCount = 0;
        }
      }

      if (diff >= 2000) {
        print('⏱️ BACKGROUND: Inactivity window expired');
        _waitingForInactivity = false;
        _validImpactDetected = false;
        _stableCount = 0;
      }
    }
  }

  /// Trigger PreAlarmScreen in foreground from background service
  static void _triggerFallDetectionUI(ServiceInstance service) async {
    print('📢 BACKGROUND: Requesting foreground UI...');

    // Send broadcast to app to show PreAlarmScreen
    if (service is AndroidServiceInstance) {
      // For Android: Use service method to wake app
      service.invoke('showFallAlert');
    }

    // Also send high-priority notification that launches the app
    // This will be handled by main.dart's notification handler
    service.invoke('fallDetected', {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'accMag': _accMag,
      'gyroMag': _gyroMag,
    });

    print('✅ BACKGROUND: Fall alert sent to foreground');
  }

  /// Start the background service
  static Future<bool> startService() async {
    final service = FlutterBackgroundService();
    return await service.startService();
  }

  /// Stop the background service
  static Future<void> stopService() async {
    final service = FlutterBackgroundService();
    service.invoke('stopService');
  }

  /// Check if background service is running
  static Future<bool> isServiceRunning() async {
    final service = FlutterBackgroundService();
    return await service.isRunning();
  }
}
