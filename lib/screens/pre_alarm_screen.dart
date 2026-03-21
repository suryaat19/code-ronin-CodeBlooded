import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

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
  late stt.SpeechToText _speechToText;
  bool _isListening = false;
  String _spokenText = '';
  bool _voiceResponseReceived = false;

  @override
  void initState() {
    super.initState();
    _speechToText = stt.SpeechToText();
    _initializeAlarm();
    _initializeSpeech();
  }

  Future<void> _initializeSpeech() async {
    try {
      bool available = await _speechToText.initialize(
        onError: (error) {
          print('🎤 Speech recognition error: $error');
          _startVoiceListening();
        },
        onStatus: (status) {
          print('🎤 Speech status: $status');
        },
      );
      if (available) {
        print('✅ Speech recognition initialized');
      }
    } catch (e) {
      print('❌ Error initializing speech: $e');
    }
  }

  Future<void> _initializeAlarm() async {
    // Vibration pattern - heavy impact
    if (await Vibration.hasVibrator() ?? false) {
      await Vibration.vibrate(duration: 500);
    }

    // TTS alert
    await _tts.setLanguage("en-US");
    await _tts.speak('Fall detected. Are you okay? Say "I am okay" or tap to cancel. Sending SOS in 15 seconds.');

    // Start countdown
    _startCountdown();

    // Flashing effect
    _startFlashing();

    // Start listening for voice response
    await Future.delayed(const Duration(milliseconds: 500));
    _startVoiceListening();
  }

  void _startVoiceListening() async {
    if (!_speechToText.isAvailable) {
      await _initializeSpeech();
    }

    if (_speechToText.isAvailable && !_isListening) {
      setState(() {
        _isListening = true;
        _spokenText = '';
      });

      try {
        await _speechToText.listen(
          onResult: (result) {
            setState(() {
              _spokenText = result.recognizedWords.toLowerCase();
            });

            // Check if user said they're okay
            if (result.finalResult) {
              _checkVoiceResponse(_spokenText);
            }
          },
          listenFor: const Duration(seconds: 5),
          pauseFor: const Duration(seconds: 2),
          partialResults: true,
          cancelOnError: false,
          listenMode: stt.ListenMode.search,
        );

        print('🎤 Voice listening started');
      } catch (e) {
        print('❌ Error starting voice listening: $e');
        setState(() {
          _isListening = false;
        });
      }
    }
  }

  void _checkVoiceResponse(String response) {
    print('🎤 Voice response: $response');

    // Keywords to check if user is okay
    const okayKeywords = ['okay', 'ok', 'i am okay', 'im okay', 'yes', 'fine', 'alright', 'all right', 'good'];

    if (okayKeywords.any((keyword) => response.contains(keyword))) {
      print('✅ User confirmed they are okay - canceling SOS');
      _tts.speak('Thank you for confirming. Alarm canceled.');
      _voiceResponseReceived = true;
      _cancelAlarm();
    } else {
      print('❌ No confirmation detected - resuming voice listening');
      _startVoiceListening();
    }
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
    if (_speechToText.isListening) {
      _speechToText.stop();
    }
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
    if (_speechToText.isListening) {
      _speechToText.stop();
    }
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
                // Voice input indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _isListening ? Colors.blue : Colors.grey.shade700,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isListening ? Colors.lightBlue : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isListening)
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.lightBlue,
                            shape: BoxShape.circle,
                          ),
                          margin: const EdgeInsets.only(right: 8),
                          child: const Center(
                            child: SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.lightBlue,
                                ),
                              ),
                            ),
                          ),
                        ),
                      Text(
                        _isListening ? '🎤 Listening...' : '🎤 Ready to listen',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_spokenText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Heard: "$_spokenText"',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 20),
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
