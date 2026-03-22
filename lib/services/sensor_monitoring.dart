import 'package:sensors_plus/sensors_plus.dart';
import 'dart:math';
import 'dart:async';

class SensorMonitoring {
  // ===== TUNED THRESHOLDS =====
  // Impact: use RAW (unsmoothed) to preserve sharp spikes
  static const double ACC_IMPACT_THRESHOLD = 12.0; // m/s2 - raw spike after ground hit
  static const double FREEFALL_THRESHOLD = 4.0;    // Free-fall: acc drops well below gravity
  static const double GYRO_THRESHOLD = 2.0;        // Body rotation during fall (rad/s)
  static const double GYRO_UPPER_LIMIT = 20.0;     // Ignore extreme spins (phone thrown)
  static const double HARD_IMPACT_THRESHOLD = 30.0; // Extreme impact - skip free-fall
  static const int COOLDOWN_SEC = 5;

  // Fainting detection thresholds
  static const double FAINT_ACC_DEVIATION = 2.5;   // Deviation from gravity during collapse
  static const double FAINT_GYRO_MAX = 3.0;        // Low gyro = body collapse, not phone shake
  static const int FAINT_CONSECUTIVE_REQUIRED = 5;  // Sustained abnormal readings
  static const double GRAVITY = 9.81;

  // Inactivity (device lying still after impact)
  static const double STABLE_ACC_LOW = 7.0;   // Wider window for noisy sensors
  static const double STABLE_ACC_HIGH = 13.0;
  static const double STABLE_GYRO_MAX = 1.5;  // Device not rotating
  static const int STABLE_REQUIRED = 3;        // Only 3 stable readings needed (was 5)
  static const int INACTIVITY_TIMEOUT_MS = 5000; // 5 seconds window (was 3s)
  static const int INACTIVITY_START_MS = 200;    // Start checking after 200ms (was 300ms)

  // ===== STATE =====
  static double _accMag = 0;       // Smoothed accel for UI
  static double _rawAccMag = 0;    // Raw accel for impact detection
  static double _gyroMag = 0;
  static DateTime? _lastTrigger;

  // ===== FREE-FALL TRACKING =====
  static int _freefallCount = 0;
  static bool _freefallDetected = false;
  static DateTime? _freefallEndTime;

  // ===== IMPACT TRACKING =====
  static bool _waitingForInactivity = false;
  static bool _validImpact = false;
  static DateTime? _impactTime;
  static int _stableCount = 0;

  // ===== FAINTING TRACKING =====
  static int _faintCount = 0;  // Consecutive abnormal-gravity + low-gyro readings

  // ===== SMOOTHING =====
  static final List<double> _accBuffer = [];
  static final List<double> _gyroBuffer = [];
  static const int SMOOTH_WINDOW = 3;

  static StreamSubscription? _accelerometerSubscription;
  static StreamSubscription? _gyroscopeSubscription;

  // ===== PUBLIC GETTERS for UI =====
  static double get currentAccMag => _accMag;
  static double get currentGyroMag => _gyroMag;
  static double get currentRawAccMag => _rawAccMag;
  static String get currentPhase {
    if (_waitingForInactivity) return 'Checking inactivity ($_stableCount/$STABLE_REQUIRED)';
    if (_freefallDetected) return 'Free-fall detected!';
    if (_faintCount >= 2) return 'Possible faint ($_faintCount/$FAINT_CONSECUTIVE_REQUIRED)';
    return 'Monitoring';
  }

  /// Start monitoring sensors for fall detection
  static void startMonitoring({
    required Function(bool) onFallDetected,
  }) {
    // Reset state on start
    _resetState();
    _accBuffer.clear();
    _gyroBuffer.clear();

    try {
      // Listen to accelerometer (includes gravity - magnitude ~9.81 at rest)
      _accelerometerSubscription = accelerometerEventStream().listen(
        (AccelerometerEvent event) {
          _processSensorData(event, onFallDetected);
        },
        onError: (error) {
          print('Accelerometer error: $error');
        },
      );

      // Listen to gyroscope
      _gyroscopeSubscription = gyroscopeEventStream().listen(
        (GyroscopeEvent event) {
          _processGyroData(event);
        },
        onError: (error) {
          print('Gyroscope error: $error');
        },
      );

      print('[START] Sensor monitoring started - thresholds: '
          'freefall<$FREEFALL_THRESHOLD, impact>$ACC_IMPACT_THRESHOLD, '
          'gyro>$GYRO_THRESHOLD');
    } catch (e) {
      print('Error starting sensor monitoring: $e');
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
    double rawAcc = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

    _rawAccMag = rawAcc;                          // Keep raw for impact spike
    _accMag = _smooth(rawAcc, _accBuffer);         // Smoothed for free-fall & stability

    _checkFall(onFallDetected);
  }

  /// Process gyroscope data
  static void _processGyroData(GyroscopeEvent event) {
    double rawGyro = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    _gyroMag = _smooth(rawGyro, _gyroBuffer);
  }

  // ===================================================================
  //  CORE DETECTION LOGIC
  //  Pipeline: Free-fall -> Impact -> Inactivity -> FALL CONFIRMED
  //  Fallback: Hard Impact + Rotation -> Inactivity -> FALL CONFIRMED
  // ===================================================================
  static void _checkFall(Function(bool) onFallDetected) {
    final now = DateTime.now();

    // -- Cooldown --
    if (_lastTrigger != null &&
        now.difference(_lastTrigger!).inSeconds < COOLDOWN_SEC) {
      return;
    }

    // -- Ignore extreme spin (phone thrown, not a fall) --
    if (_gyroMag > GYRO_UPPER_LIMIT) {
      print('[IGNORE] Extreme spin detected (${_gyroMag.toStringAsFixed(1)} rad/s), ignoring');
      _resetState();
      return;
    }

    // ------------------------------------------------
    // PHASE 1: Detect free-fall (acceleration drops well below gravity)
    // During free-fall, accelerometer reads near 0 (no contact force)
    // A 2m fall gives ~0.64s of free-fall
    // ------------------------------------------------
    if (_accMag < FREEFALL_THRESHOLD && !_freefallDetected && !_waitingForInactivity) {
      _freefallCount++;
      if (_freefallCount >= 2) {  // Only need 2 consecutive (was 3)
        _freefallDetected = true;
        _freefallEndTime = now;
        print('[FREE-FALL] Acc: ${_accMag.toStringAsFixed(2)} m/s2 '
            '(${_freefallCount} readings)');
      }
      return;
    }

    // Reset free-fall counter if not in free-fall and not yet confirmed
    if (_accMag >= FREEFALL_THRESHOLD && !_freefallDetected) {
      _freefallCount = 0;
    }

    // ------------------------------------------------
    // PHASE 2: Detect impact after free-fall
    // Use RAW (unsmoothed) acceleration to catch the spike
    // ------------------------------------------------
    if (_freefallDetected && !_waitingForInactivity) {
      final timeSinceFreefallEnd = now.difference(_freefallEndTime!).inMilliseconds;

      // Impact must happen within 1.5s of free-fall ending
      if (timeSinceFreefallEnd > 1500) {
        print('[TIMEOUT] No impact within 1.5s of free-fall, resetting');
        _resetState();
        return;
      }

      // Use RAW value for impact - smoothing kills spikes
      if (_rawAccMag > ACC_IMPACT_THRESHOLD) {
        _waitingForInactivity = true;
        _validImpact = true;
        _impactTime = now;
        _stableCount = 0;

        print('[IMPACT] After free-fall! '
            'Raw: ${_rawAccMag.toStringAsFixed(2)} m/s2 '
            '(threshold: $ACC_IMPACT_THRESHOLD), '
            'Gyro: ${_gyroMag.toStringAsFixed(2)} rad/s');
        return;
      }
    }

    // ------------------------------------------------
    // FALLBACK A: Hard impact + rotation WITHOUT free-fall
    // (handles tripping, stumbling where free-fall is too brief)
    // ------------------------------------------------
    if (!_waitingForInactivity && !_freefallDetected) {
      bool hardImpact = _rawAccMag > ACC_IMPACT_THRESHOLD;
      bool rotation = _gyroMag > GYRO_THRESHOLD;

      if (hardImpact && rotation) {
        _waitingForInactivity = true;
        _validImpact = true;
        _impactTime = now;
        _stableCount = 0;

        print('[IMPACT+ROTATION] No free-fall - '
            'Raw: ${_rawAccMag.toStringAsFixed(2)} m/s2, '
            'Gyro: ${_gyroMag.toStringAsFixed(2)} rad/s');
        return;
      }
    }

    // ------------------------------------------------
    // FALLBACK B: Extreme impact - skip everything
    // (very hard hit, definitely not normal activity)
    // ------------------------------------------------
    if (!_waitingForInactivity && _rawAccMag > HARD_IMPACT_THRESHOLD) {
      _waitingForInactivity = true;
      _validImpact = true;
      _impactTime = now;
      _stableCount = 0;

      print('[EXTREME IMPACT] Raw: ${_rawAccMag.toStringAsFixed(2)} m/s2 '
          '(threshold: $HARD_IMPACT_THRESHOLD)');
      return;
    }

    // ------------------------------------------------
    // FALLBACK C: FAINTING DETECTION
    // Fainting pattern: body slowly collapses -> acc deviates from gravity
    // with LOW gyro (not a phone shake - person is going limp)
    // Unlike tripping, fainting has minimal rotation and a slower onset
    // ------------------------------------------------
    if (!_waitingForInactivity && !_freefallDetected) {
      double accDeviation = (_accMag - GRAVITY).abs();
      bool abnormalGravity = accDeviation > FAINT_ACC_DEVIATION;
      bool lowGyro = _gyroMag < FAINT_GYRO_MAX;

      if (abnormalGravity && lowGyro) {
        _faintCount++;
        if (_faintCount >= FAINT_CONSECUTIVE_REQUIRED) {
          _waitingForInactivity = true;
          _validImpact = true;
          _impactTime = now;
          _stableCount = 0;
          _faintCount = 0;

          print('[FAINT DETECTED] '
              'Acc deviation: ${accDeviation.toStringAsFixed(2)} m/s2 '
              '(sustained ${FAINT_CONSECUTIVE_REQUIRED} readings), '
              'Gyro: ${_gyroMag.toStringAsFixed(2)} rad/s (low = body collapse)');
          return;
        }
      } else {
        // Reset if pattern breaks - need consecutive readings
        if (_faintCount > 0) _faintCount = 0;
      }
    }

    // ------------------------------------------------
    // PHASE 3: Check inactivity (device lying still after impact)
    // Person has fallen and is not moving
    // ------------------------------------------------
    if (_waitingForInactivity && _validImpact && _impactTime != null) {
      final diff = now.difference(_impactTime!).inMilliseconds;

      if (diff > INACTIVITY_START_MS && diff < INACTIVITY_TIMEOUT_MS) {
        // Check if device is relatively still
        bool accStable = _accMag > STABLE_ACC_LOW && _accMag < STABLE_ACC_HIGH;
        bool gyroStable = _gyroMag < STABLE_GYRO_MAX;

        if (accStable && gyroStable) {
          _stableCount++;
          print('[STABLE] Reading $_stableCount/$STABLE_REQUIRED '
              '(acc: ${_accMag.toStringAsFixed(2)}, gyro: ${_gyroMag.toStringAsFixed(2)})');

          if (_stableCount >= STABLE_REQUIRED) {
            print('===============================');
            print('  FALL CONFIRMED!');
            print('  Acc: ${_accMag.toStringAsFixed(2)} m/s2');
            print('  Gyro: ${_gyroMag.toStringAsFixed(2)} rad/s');
            print('===============================');

            _lastTrigger = now;
            _resetState();
            onFallDetected(true);
          }
        }
        // NOTE: Do NOT decrement stableCount on noisy readings
        // Just skip and wait for next stable reading
      }

      // Timeout - no inactivity detected, probably not a fall
      if (diff >= INACTIVITY_TIMEOUT_MS) {
        print('[TIMEOUT] Inactivity timeout ($INACTIVITY_TIMEOUT_MS ms), resetting');
        _resetState();
      }
    }
  }

  /// Reset detection state
  static void _resetState() {
    _freefallCount = 0;
    _freefallDetected = false;
    _freefallEndTime = null;
    _waitingForInactivity = false;
    _validImpact = false;
    _impactTime = null;
    _stableCount = 0;
    _faintCount = 0;
  }

  /// Stop monitoring sensors
  static void stopMonitoring() {
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _accelerometerSubscription = null;
    _gyroscopeSubscription = null;
    _resetState();
    _accBuffer.clear();
    _gyroBuffer.clear();
    print('[STOP] Sensor monitoring stopped');
  }

  /// Get current acceleration as g-force
  static double getCurrentAccelerationG(AccelerometerEvent event) {
    final double magnitude = sqrt(
      (event.x * event.x) + (event.y * event.y) + (event.z * event.z),
    );
    return magnitude / 9.81;
  }
}
