import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Advanced Fall Detector Widget with real-time sensor visualization
class AdvancedFallDetector extends StatefulWidget {
  final VoidCallback? onFallDetected;

  const AdvancedFallDetector({
    Key? key,
    this.onFallDetected,
  }) : super(key: key);

  @override
  State<AdvancedFallDetector> createState() => _AdvancedFallDetectorState();
}

class _AdvancedFallDetectorState extends State<AdvancedFallDetector> {
  // ====== Thresholds ======
  double ACC_THRESHOLD = 22.0;
  double GYRO_THRESHOLD = 4.0;
  int COOLDOWN_SEC = 5;

  // ====== State ======
  double accMag = 0;
  double gyroMag = 0;
  DateTime? lastTrigger;

  // ====== Smoothing buffers ======
  List<double> accBuffer = [];
  List<double> gyroBuffer = [];

  // ====== TTS ======
  final FlutterTts tts = FlutterTts();

  // ====== Subscriptions ======
  StreamSubscription? accSub;
  StreamSubscription? gyroSub;

  @override
  void initState() {
    super.initState();
    startSensors();
  }

  @override
  void dispose() {
    accSub?.cancel();
    gyroSub?.cancel();
    super.dispose();
  }

  // ====== Start sensors ======
  void startSensors() {
    accSub = accelerometerEvents.listen((event) {
      double rawAcc =
          sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      setState(() {
        accMag = smooth(rawAcc, accBuffer);
      });
      checkFall();
    });

    gyroSub = gyroscopeEvents.listen((event) {
      double rawGyro =
          sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      setState(() {
        gyroMag = smooth(rawGyro, gyroBuffer);
      });
    });
  }

  // ====== Smoothing ======
  double smooth(double value, List<double> buffer) {
    buffer.add(value);
    if (buffer.length > 5) buffer.removeAt(0);
    return buffer.reduce((a, b) => a + b) / buffer.length;
  }

  // ====== Detection Logic ======
  void checkFall() {
    final now = DateTime.now();

    // Cooldown
    if (lastTrigger != null &&
        now.difference(lastTrigger!).inSeconds < COOLDOWN_SEC) {
      return;
    }

    bool impact = accMag > ACC_THRESHOLD;
    bool rotation = gyroMag > GYRO_THRESHOLD;

    if (impact && rotation) {
      lastTrigger = now;
      onFallDetected();
    }
  }

  // ====== On Fall Detected ======
  void onFallDetected() async {
    print("🚨 FALL DETECTED 🚨");

    await tts.speak("Fall detected. Are you okay?");
    if (await Vibration.hasVibrator() ?? false) {
      await Vibration.vibrate(duration: 1000);
    }

    widget.onFallDetected?.call();
    startCountdown();
  }

  // ====== 10-second Countdown ======
  void startCountdown() {
    int seconds = 10;

    Timer.periodic(Duration(seconds: 1), (timer) async {
      seconds--;

      if (seconds == 5) {
        await tts.speak("Sending alert in 5 seconds");
      }

      if (seconds <= 0) {
        timer.cancel();
        onFallConfirmed();
      }
    });
  }

  // ====== FINAL ACTION (SOS) ======
  void onFallConfirmed() {
    print("🆘 SENDING SOS 🆘");
    // TODO: Add SMS + Call logic here
  }

  // ====== UI ======
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        title: const Text("Advanced Fall Detection"),
        backgroundColor: Colors.grey[900],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Accelerometer Display
              _buildSensorCard(
                title: "Acceleration (m/s²)",
                value: accMag.toStringAsFixed(2),
                threshold: ACC_THRESHOLD,
                isTriggered: accMag > ACC_THRESHOLD,
                color: Colors.blue,
              ),
              const SizedBox(height: 20),

              // Gyroscope Display
              _buildSensorCard(
                title: "Rotation (rad/s)",
                value: gyroMag.toStringAsFixed(2),
                threshold: GYRO_THRESHOLD,
                isTriggered: gyroMag > GYRO_THRESHOLD,
                color: Colors.orange,
              ),
              const SizedBox(height: 30),

              // Status Display
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: (accMag > ACC_THRESHOLD && gyroMag > GYRO_THRESHOLD)
                      ? Colors.red
                      : Colors.green,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  (accMag > ACC_THRESHOLD && gyroMag > GYRO_THRESHOLD)
                      ? "⚠️ FALL ALERT"
                      : "✓ Monitoring Active",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSensorCard({
    required String title,
    required String value,
    required double threshold,
    required bool isTriggered,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTriggered ? Colors.red : color,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: isTriggered ? Colors.red : color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Threshold: ${threshold.toStringAsFixed(1)}",
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
