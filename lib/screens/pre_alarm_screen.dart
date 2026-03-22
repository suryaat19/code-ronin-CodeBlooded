import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart';
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
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isFlashing = true;
  bool _isListening = false;
  bool _isCancelled = false;
  String _lastHeardWords = '';
  Timer? _flashTimer;

  // Keywords that will cancel the SOS
  static const List<String> _cancelKeywords = [
    'stop',
    'abort',
    'cancel',
    'no',
    'okay',
    'i\'m fine',
    'i am fine',
    'fine',
    'false alarm',
    'i am okay',
    
  ];

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
    await HapticFeedback.heavyImpact();

    // TTS alert
    await _tts.setLanguage("en-US");
    await _tts.speak(
      'Fall detected. Sending SOS in 15 seconds. Say stop or tap anywhere to cancel.',
    );

    // Start countdown
    _startCountdown();

    // Flashing effect
    _startFlashing();

    // Wait for TTS to finish, then start listening
    _tts.setCompletionHandler(() {
      _startListening();
    });
  }

  /// Initialize and start speech recognition
  Future<void> _startListening() async {
    try {
      bool available = await _speech.initialize(
        onError: (error) {
          print('Speech recognition error: ${error.errorMsg}');
          // Restart listening if it stopped due to error
          if (mounted && error.errorMsg != 'error_busy') {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) _startListening();
            });
          }
        },
        onStatus: (status) {
          print('Speech recognition status: $status');
          if (status == 'notListening' && mounted) {
            setState(() => _isListening = false);
            // Auto-restart listening if countdown is still active
            if (_secondsRemaining > 0) {
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted && _secondsRemaining > 0) _startListening();
              });
            }
          }
        },
      );

      if (available && mounted) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (result) {
            final words = result.recognizedWords.toLowerCase();
            if (mounted) {
              setState(() => _lastHeardWords = words);
            }
            _checkForCancelCommand(words);
          },
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
          listenOptions: stt.SpeechListenOptions(
            listenMode: stt.ListenMode.dictation,
          ),
        );
      }
    } catch (e) {
      print('Speech recognition init error: $e');
    }
  }

  /// Check if spoken words contain a cancel keyword
  void _checkForCancelCommand(String words) {
    for (final keyword in _cancelKeywords) {
      if (words.contains(keyword)) {
        print('[VOICE] Cancel keyword detected: "$keyword" in "$words"');
        _cancelAlarm();
        return;
      }
    }
  }

  void _startFlashing() {
    _flashTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
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
    if (_isCancelled) return; // Prevent double-pop
    _isCancelled = true;

    _countdownTimer.cancel();
    _flashTimer?.cancel();
    _tts.stop();
    _speech.stop();
    widget.onCancel?.call();

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alarm canceled')),
      );
    }
  }

  Future<void> _sendSOS() async {
    _speech.stop();
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
    _flashTimer?.cancel();
    _tts.stop();
    _speech.stop();
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
          label: 'Fall detected alarm. Tap or say stop to cancel.',
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

                // Mic listening indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isListening ? Icons.mic : Icons.mic_off,
                      color: _isListening ? Colors.white : Colors.white38,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isListening ? 'Listening...' : 'Mic starting...',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _isListening ? Colors.white : Colors.white38,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Show last heard words for feedback
                if (_lastHeardWords.isNotEmpty)
                  Text(
                    '"$_lastHeardWords"',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white54,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 20),

                Text(
                  'Tap or say "Stop" to cancel',
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
