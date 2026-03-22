import 'package:sensors_plus/sensors_plus.dart';
import 'dart:math';
import 'dart:async';

/// Timestamped sensor sample for sliding window
class _SensorSample {
  final double value;
  final DateTime time;
  _SensorSample(this.value, this.time);
}

class SensorMonitoring {
  // ===== THRESHOLDS =====
  static const double FREEFALL_THRESHOLD = 5.0;      // < 0.5g
  static const double IMPACT_THRESHOLD = 12.0;        // Impact spike (was 25 — too high)
  static const double IMPACT_AFTER_FREEFALL = 10.0;   // Lower bar if free-fall confirmed
  static const double HARD_IMPACT_THRESHOLD = 25.0;   // Extreme impact
  static const double ROTATION_THRESHOLD = 2.0;       // rad/s for fall rotation
  static const double GYRO_UPPER_LIMIT = 20.0;        // Ignore phone thrown
  static const double GRAVITY = 9.81;
  static const int COOLDOWN_SEC = 5;

  // Inactivity
  static const double INACTIVITY_VARIANCE_THRESHOLD = 3.0;  // Low variance = still
  static const int INACTIVITY_WINDOW_MS = 2000;              // 2 sec window

  // Spike filter
  static const int MAX_SPIKES_PER_SEC = 3;            // > 3 spikes = shaking
  static const double SPIKE_LEVEL = 12.0;              // What counts as a spike

  // Fainting
  static const double FAINT_ACC_DEVIATION = 2.5;
  static const double FAINT_GYRO_MAX = 3.0;
  static const int FAINT_CONSECUTIVE_REQUIRED = 5;

  // Scoring
  static const int SCORE_FREEFALL = 2;
  static const int SCORE_IMPACT = 2;
  static const int SCORE_INACTIVITY = 3;
  static const int SCORE_ROTATION = 2;
  static const int PENALTY_SHAKING = -3;
  static const int FALL_SCORE_THRESHOLD = 5;

  // ===== SLIDING WINDOW BUFFERS =====
  static final List<_SensorSample> _accHistory = [];
  static final List<_SensorSample> _gyroHistory = [];
  static const int WINDOW_DURATION_MS = 3000;  // 3 sec buffer

  // ===== STATE =====
  static double _accMag = 0;
  static double _rawAccMag = 0;
  static double _gyroMag = 0;
  static DateTime? _lastTrigger;

  // ===== SMOOTHING =====
  static final List<double> _accSmoothBuf = [];
  static final List<double> _gyroSmoothBuf = [];
  static const int SMOOTH_WINDOW = 3;

  // ===== DETECTION STAGES =====
  static bool _freefallDetected = false;
  static DateTime? _freefallTime;
  static int _freefallCount = 0;

  static bool _impactDetected = false;
  static DateTime? _impactTime;

  static bool _rotationDetected = false;

  static bool _waitingForInactivity = false;
  static bool _scoringDone = false;

  // ===== FAINTING =====
  static int _faintCount = 0;

  // ===== DEBUG =====
  static int _debugCounter = 0;

  // ===== SUBSCRIPTIONS =====
  static StreamSubscription? _accelerometerSubscription;
  static StreamSubscription? _gyroscopeSubscription;

  // ===== PUBLIC GETTERS =====
  static double get currentAccMag => _accMag;
  static double get currentGyroMag => _gyroMag;
  static double get currentRawAccMag => _rawAccMag;

  /// Expose sliding window values for ML feature extraction
  static List<double> get accWindow =>
      _accHistory.map((s) => s.value).toList();
  static List<double> get gyroWindow =>
      _gyroHistory.map((s) => s.value).toList();

  static String get currentPhase {
    if (_waitingForInactivity) return 'Checking inactivity...';
    if (_impactDetected) return 'Impact detected';
    if (_freefallDetected) return 'Free-fall detected!';
    if (_faintCount >= 2) return 'Possible faint ($_faintCount/$FAINT_CONSECUTIVE_REQUIRED)';
    return 'Monitoring';
  }

  // ==================================================================
  //  START / STOP
  // ==================================================================

  static void startMonitoring({
    required Function(bool) onFallDetected,
  }) {
    _resetState();
    _accHistory.clear();
    _gyroHistory.clear();
    _accSmoothBuf.clear();
    _gyroSmoothBuf.clear();

    try {
      _accelerometerSubscription = accelerometerEventStream().listen(
        (AccelerometerEvent event) {
          _processAccelerometer(event, onFallDetected);
        },
        onError: (error) {
          print('Accelerometer error: $error');
        },
      );

      _gyroscopeSubscription = gyroscopeEventStream().listen(
        (GyroscopeEvent event) {
          _processGyroscope(event);
        },
        onError: (error) {
          print('Gyroscope error: $error');
        },
      );

      print('[START] Multi-stage scoring pipeline active');
    } catch (e) {
      print('Error starting sensors: $e');
    }
  }

  static void stopMonitoring() {
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _accelerometerSubscription = null;
    _gyroscopeSubscription = null;
    _resetState();
    _accHistory.clear();
    _gyroHistory.clear();
    _accSmoothBuf.clear();
    _gyroSmoothBuf.clear();
    print('[STOP] Sensor monitoring stopped');
  }

  // ==================================================================
  //  SENSOR PROCESSING
  // ==================================================================

  static double _smooth(double value, List<double> buffer) {
    buffer.add(value);
    if (buffer.length > SMOOTH_WINDOW) buffer.removeAt(0);
    return buffer.reduce((a, b) => a + b) / buffer.length;
  }

  static void _processAccelerometer(
    AccelerometerEvent event,
    Function(bool) onFallDetected,
  ) {
    final now = DateTime.now();
    double raw = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

    _rawAccMag = raw;
    _accMag = _smooth(raw, _accSmoothBuf);

    // Add to sliding window
    _accHistory.add(_SensorSample(raw, now));
    _trimHistory(_accHistory, now);

    _checkFall(onFallDetected);
  }

  static void _processGyroscope(GyroscopeEvent event) {
    final now = DateTime.now();
    double raw = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    _gyroMag = _smooth(raw, _gyroSmoothBuf);

    _gyroHistory.add(_SensorSample(raw, now));
    _trimHistory(_gyroHistory, now);
  }

  /// Trim samples older than the window duration
  static void _trimHistory(List<_SensorSample> history, DateTime now) {
    history.removeWhere(
      (s) => now.difference(s.time).inMilliseconds > WINDOW_DURATION_MS,
    );
  }

  // ==================================================================
  //  SLIDING WINDOW FEATURE EXTRACTION
  // ==================================================================

  /// Compute variance of values in the history within the given time window
  static double _computeVariance(List<_SensorSample> history, int windowMs) {
    final now = DateTime.now();
    final samples = history
        .where((s) => now.difference(s.time).inMilliseconds <= windowMs)
        .map((s) => s.value)
        .toList();
    if (samples.length < 2) return 0.0;

    final mean = samples.reduce((a, b) => a + b) / samples.length;
    final variance = samples.map((v) => (v - mean) * (v - mean))
        .reduce((a, b) => a + b) / samples.length;
    return variance;
  }

  /// Count spikes above the spike level in the last N ms
  static int _countSpikes(List<_SensorSample> history, int windowMs) {
    final now = DateTime.now();
    return history
        .where((s) =>
            now.difference(s.time).inMilliseconds <= windowMs &&
            s.value > SPIKE_LEVEL)
        .length;
  }

  /// Check if there is continuous high motion after impact
  static bool _hasContinuousMotion(int windowMs) {
    final variance = _computeVariance(_accHistory, windowMs);
    return variance > 5.0; // High variance = still moving
  }

  /// Check if gyro had a rotation event in recent history
  static bool _hadRotation(int windowMs) {
    final now = DateTime.now();
    return _gyroHistory.any((s) =>
        now.difference(s.time).inMilliseconds <= windowMs &&
        s.value > ROTATION_THRESHOLD);
  }

  // ==================================================================
  //  CORE DETECTION LOGIC — MULTI-STAGE SCORING
  // ==================================================================

  static void _checkFall(Function(bool) onFallDetected) {
    final now = DateTime.now();

    // Debug logging every 50 readings
    _debugCounter++;
    if (_debugCounter % 50 == 0) {
      print('[SENSOR] acc: ${_accMag.toStringAsFixed(1)}, '
          'raw: ${_rawAccMag.toStringAsFixed(1)}, '
          'gyro: ${_gyroMag.toStringAsFixed(1)} | '
          'phase: $currentPhase');
    }

    // -- Cooldown --
    if (_lastTrigger != null &&
        now.difference(_lastTrigger!).inSeconds < COOLDOWN_SEC) {
      return;
    }

    // -- Ignore extreme spin (phone thrown) --
    if (_gyroMag > GYRO_UPPER_LIMIT) {
      _resetState();
      return;
    }

    // ------------------------------------------------
    // STAGE 1: Free-fall detection
    // ------------------------------------------------
    if (_accMag < FREEFALL_THRESHOLD && !_freefallDetected && !_waitingForInactivity) {
      _freefallCount++;
      if (_freefallCount >= 2) {
        _freefallDetected = true;
        _freefallTime = now;
        print('[STAGE 1] Free-fall: ${_accMag.toStringAsFixed(2)} m/s2');
      }
      return;
    }

    // Reset free-fall counter if not sustained
    if (_accMag >= FREEFALL_THRESHOLD && !_freefallDetected) {
      _freefallCount = 0;
    }

    // ------------------------------------------------
    // STAGE 2: Impact detection
    // ------------------------------------------------
    // Path A: Impact after free-fall (lower threshold since free-fall already confirmed)
    if (_freefallDetected && !_impactDetected && !_waitingForInactivity) {
      final timeSinceFF = now.difference(_freefallTime!).inMilliseconds;
      if (timeSinceFF > 1500) {
        print('[TIMEOUT] No impact within 1.5s of free-fall');
        _resetState();
        return;
      }
      if (_rawAccMag > IMPACT_AFTER_FREEFALL) {
        _impactDetected = true;
        _impactTime = now;
        _waitingForInactivity = true;
        print('[STAGE 2A] Impact after free-fall: ${_rawAccMag.toStringAsFixed(2)} m/s2 '
            '(threshold: $IMPACT_AFTER_FREEFALL)');
        return;
      }
    }

    // Path B: Impact + rotation without free-fall (trip/stumble)
    if (!_waitingForInactivity && !_freefallDetected && !_impactDetected) {
      if (_rawAccMag > IMPACT_THRESHOLD && _gyroMag > ROTATION_THRESHOLD) {
        _impactDetected = true;
        _impactTime = now;
        _waitingForInactivity = true;
        print('[STAGE 2] Impact+rotation (no free-fall): '
            '${_rawAccMag.toStringAsFixed(2)} m/s2, '
            'gyro: ${_gyroMag.toStringAsFixed(2)} rad/s');
        return;
      }
    }

    // Path C: Extreme impact — skip free-fall requirement
    if (!_waitingForInactivity && _rawAccMag > HARD_IMPACT_THRESHOLD) {
      _impactDetected = true;
      _impactTime = now;
      _waitingForInactivity = true;
      print('[STAGE 2] Extreme impact: ${_rawAccMag.toStringAsFixed(2)} m/s2');
      return;
    }

    // ------------------------------------------------
    // FAINTING FALLBACK: slow collapse detection
    // ------------------------------------------------
    if (!_waitingForInactivity && !_freefallDetected && !_impactDetected) {
      double accDeviation = (_accMag - GRAVITY).abs();
      if (accDeviation > FAINT_ACC_DEVIATION && _gyroMag < FAINT_GYRO_MAX) {
        _faintCount++;
        if (_faintCount >= FAINT_CONSECUTIVE_REQUIRED) {
          _impactDetected = true; // Treat faint as soft impact
          _impactTime = now;
          _waitingForInactivity = true;
          _faintCount = 0;
          print('[FAINT] Slow collapse detected: '
              'deviation: ${accDeviation.toStringAsFixed(2)} m/s2');
          return;
        }
      } else {
        if (_faintCount > 0) _faintCount = 0;
      }
    }

    // ------------------------------------------------
    // STAGE 3 + 4: Inactivity + Rotation → SCORING
    // ------------------------------------------------
    if (_waitingForInactivity && _impactDetected && _impactTime != null) {
      final elapsed = now.difference(_impactTime!).inMilliseconds;

      // Wait at least 500ms after impact before checking inactivity
      if (elapsed < 500) return;

      // Timeout after 5 seconds
      if (elapsed > 5000) {
        print('[TIMEOUT] No inactivity after 5s, resetting');
        _resetState();
        return;
      }

      // Only run scoring once when inactivity window has enough data (>1.5s)
      if (elapsed >= 1500 && !_scoringDone) {
        _scoringDone = true;
        _runScoring(onFallDetected);
      }
    }
  }

  // ==================================================================
  //  SCORING SYSTEM
  // ==================================================================

  static void _runScoring(Function(bool) onFallDetected) {
    int score = 0;
    final reasons = <String>[];

    // Stage 1: Free-fall
    if (_freefallDetected) {
      score += SCORE_FREEFALL;
      reasons.add('+$SCORE_FREEFALL free-fall');
    }

    // Stage 2: Impact
    if (_impactDetected) {
      score += SCORE_IMPACT;
      reasons.add('+$SCORE_IMPACT impact');
    }

    // Stage 3: Inactivity (variance check on last 1.5s)
    final accVariance = _computeVariance(_accHistory, 1500);
    final gyroVariance = _computeVariance(_gyroHistory, 1500);
    final isInactive = accVariance < INACTIVITY_VARIANCE_THRESHOLD &&
        gyroVariance < INACTIVITY_VARIANCE_THRESHOLD;
    if (isInactive) {
      score += SCORE_INACTIVITY;
      reasons.add('+$SCORE_INACTIVITY inactivity (accVar: ${accVariance.toStringAsFixed(2)}, '
          'gyroVar: ${gyroVariance.toStringAsFixed(2)})');
    }

    // Stage 4: Rotation check (did gyro spike in last 3s?)
    if (_hadRotation(3000)) {
      _rotationDetected = true;
      score += SCORE_ROTATION;
      reasons.add('+$SCORE_ROTATION rotation detected');
    }

    // Penalty: spike count (shaking detection)
    final spikeCount = _countSpikes(_accHistory, 1000);
    if (spikeCount > MAX_SPIKES_PER_SEC) {
      score += PENALTY_SHAKING;
      reasons.add('$PENALTY_SHAKING shaking penalty ($spikeCount spikes)');
    }

    // Penalty: continuous motion after impact
    if (_hasContinuousMotion(1500)) {
      score -= 2;
      reasons.add('-2 continuous motion');
    }

    // Log the score breakdown
    print('========== FALL SCORE ==========');
    for (final r in reasons) {
      print('  $r');
    }
    print('  TOTAL: $score / $FALL_SCORE_THRESHOLD needed');
    print('================================');

    if (score >= FALL_SCORE_THRESHOLD) {
      print('[FALL CONFIRMED] Score: $score');
      _lastTrigger = DateTime.now();
      _resetState();
      onFallDetected(true);
    } else {
      print('[REJECTED] Score too low: $score');
      // Keep waiting until timeout — don't reset yet
      // Allow re-scoring if data changes
      _scoringDone = false;
    }
  }

  // ==================================================================
  //  RESET
  // ==================================================================

  static void _resetState() {
    _freefallDetected = false;
    _freefallTime = null;
    _freefallCount = 0;
    _impactDetected = false;
    _impactTime = null;
    _rotationDetected = false;
    _waitingForInactivity = false;
    _scoringDone = false;
    _faintCount = 0;
  }

  /// Get current acceleration as g-force
  static double getCurrentAccelerationG(AccelerometerEvent event) {
    final double magnitude = sqrt(
      (event.x * event.x) + (event.y * event.y) + (event.z * event.z),
    );
    return magnitude / 9.81;
  }
}
