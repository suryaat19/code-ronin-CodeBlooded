import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';

class PreAlarmScreen extends StatefulWidget {
  final VoidCallback? onCancel;

  const PreAlarmScreen({
    Key? key,
    this.onCancel,
  }) : super(key: key);

  @override
  State<PreAlarmScreen> createState() => _PreAlarmScreenState();
}

class _PreAlarmScreenState extends State<PreAlarmScreen> {
  int _secondsRemaining = 15;
  late Timer _countdownTimer;
  final FlutterTts _tts = FlutterTts();
  bool _isFlashing = true;

  @override
  void initState() {
    super.initState();
    _initializeAlarm();
  }

  Future<void> _initializeAlarm() async {
    // Vibration pattern - heavy impact
    if (await Vibration.hasVibrator() ?? false) {
      await Vibration.vibrate(duration: 500);
    }

    // TTS alert
    await _tts.setLanguage("en-US");
    await _tts.speak('Fall detected. Sending SOS in 15 seconds. Tap anywhere on the screen to cancel.');

    // Start countdown
    _startCountdown();

    // Flashing effect
    _startFlashing();
  }

  void _startFlashing() {
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted) {
        setState(() {
          _isFlashing = !_isFlashing;
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        // Time's up - send SOS
        _countdownTimer.cancel();
        _sendSOS();
      }
    });
  }

  void _cancelAlarm() {
    _countdownTimer.cancel();
    _tts.stop();
    widget.onCancel?.call();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Alarm canceled')),
    );
  }

  Future<void> _sendSOS() async {
    _tts.speak('Sending SOS alert');
    // SMS and GPS logic will be triggered by FallDetectionEngine
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _countdownTimer.cancel();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isFlashing ? Colors.red : Colors.red.shade900,
      body: GestureDetector(
        onTap: _cancelAlarm,
        behavior: HitTestBehavior.translucent,
        child: Semantics(
          label: 'Fall detected alarm. Tap to cancel.',
          onTap: _cancelAlarm,
          button: true,
          enabled: true,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'FALL DETECTED',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 36,
                  ),
                  semanticsLabel: 'Fall Detected',
                ),
                const SizedBox(height: 40),
                Text(
                  'Sending SOS in',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '$_secondsRemaining',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 80,
                  ),
                  semanticsLabel: '$_secondsRemaining seconds remaining',
                ),
                const SizedBox(height: 20),
                Text(
                  'seconds',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 60),
                Text(
                  'Tap anywhere to cancel',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white70,
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
