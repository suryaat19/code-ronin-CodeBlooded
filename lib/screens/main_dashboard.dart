import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:torch_light/torch_light.dart';
import 'package:vibration/vibration.dart';
import 'dart:async';
import '../providers/fall_detection_provider.dart';
import '../services/fall_detection_engine.dart';
import '../services/sensor_monitoring.dart';
import 'emergency_contacts_screen.dart';

class AnimeColors {
  static const Color bg = Color(0xFF0D0D1A);
  static const Color cardBg = Color(0xFF161630);
  static const Color neonPink = Color(0xFFFF6B9D);
  static const Color neonCyan = Color(0xFF00F5FF);
  static const Color neonPurple = Color(0xFFBB86FC);
  static const Color neonBlue = Color(0xFF6C63FF);
  static const Color sakura = Color(0xFFFFB7C5);
  static const Color warmWhite = Color(0xFFF0E6FF);
  static const Color dangerRed = Color(0xFFFF4060);
  static const Color successGreen = Color(0xFF00E676);
}

class MainDashboard extends StatefulWidget {
  const MainDashboard({Key? key}) : super(key: key);

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard>
    with SingleTickerProviderStateMixin {
  late FallDetectionEngine _fallDetectionEngine;
  Timer? _uiUpdateTimer;
  bool _isDetectionEnabled = true;

  // Dynamic Island state
  String _islandMessage = '';
  IconData _islandIcon = Icons.info;
  Color _islandColor = AnimeColors.neonCyan;
  bool _islandVisible = false;
  Timer? _islandTimer;
  AnimationController? _islandAnimController;
  Animation<double>? _islandAnimation;

  // Inline Fall Alert state
  bool _fallAlertActive = false;
  int _secondsRemaining = 15;
  Timer? _countdownTimer;
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _lastHeardWords = '';
  Timer? _flashTimer;
  Timer? _vibrationTimer;
  bool _flashOn = false;

  static const List<String> _cancelKeywords = [
    'stop', 'abort', 'cancel', 'no', 'okay',
    'i\'m fine', 'i am fine', 'fine', 'false alarm', 'i am okay',
  ];

  @override
  void initState() {
    super.initState();

    _islandAnimController = AnimationController(
      duration: const Duration(milliseconds: 400),
      reverseDuration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _islandAnimation = CurvedAnimation(
      parent: _islandAnimController!,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFallDetection();
    });
  }

  void _initializeFallDetection() {
    final provider = context.read<FallDetectionProvider>();

    _fallDetectionEngine = FallDetectionEngine(
      onFallDetected: (detected) {
        if (detected && mounted) {
          provider.setFallDetected(true);
          _triggerFallAlert();
        }
      },
    );

    _fallDetectionEngine.initialize(
      emergencyContact: provider.emergencyContact,
    );

    provider.setMonitoring(true);

    _uiUpdateTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) setState(() {});
    });
  }

  // ============ Dynamic Island ============

  void _showDynamicIsland({
    required String message,
    required IconData icon,
    required Color color,
    Duration duration = const Duration(seconds: 2),
  }) {
    _islandTimer?.cancel();

    setState(() {
      _islandMessage = message;
      _islandIcon = icon;
      _islandColor = color;
      _islandVisible = true;
    });
    _islandAnimController?.forward();

    _islandTimer = Timer(duration, () {
      _islandAnimController?.reverse().then((_) {
        if (mounted) setState(() => _islandVisible = false);
      });
    });
  }

  // ============ Inline Fall Alert ============

  void _triggerFallAlert() {
    setState(() {
      _fallAlertActive = true;
      _secondsRemaining = 15;
      _lastHeardWords = '';
    });

    _showDynamicIsland(
      message: 'Fall Detected!',
      icon: Icons.warning_rounded,
      color: AnimeColors.dangerRed,
      duration: const Duration(seconds: 3),
    );

    // Start phone alerts: vibration + flashlight
    _startPhoneAlerts();

    // Start listening IMMEDIATELY (don't wait for TTS)
    _startListening();

    _tts.setLanguage("en-US");
    _tts.speak(
      'Fall detected. Sending SOS in 15 seconds. Say stop or double tap to cancel.',
    );

    _startCountdown();
  }

  void _startPhoneAlerts() {
    // Continuous vibration pattern
    _vibrationTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) async {
      if (_fallAlertActive) {
        HapticFeedback.heavyImpact();
        if (await Vibration.hasVibrator() ?? false) {
          Vibration.vibrate(duration: 800, amplitude: 255);
        }
      }
    });
    // Immediate first vibrate
    HapticFeedback.heavyImpact();
    Vibration.vibrate(duration: 800, amplitude: 255);

    // Toggle flashlight on/off
    _flashTimer = Timer.periodic(const Duration(milliseconds: 700), (_) async {
      if (!_fallAlertActive) return;
      try {
        if (_flashOn) {
          await TorchLight.disableTorch();
        } else {
          await TorchLight.enableTorch();
        }
        _flashOn = !_flashOn;
      } catch (e) {
        // Flashlight not available on this device
      }
    });
  }

  void _stopPhoneAlerts() {
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
    _flashTimer?.cancel();
    _flashTimer = null;
    Vibration.cancel();
    // Ensure flashlight is off
    try {
      TorchLight.disableTorch();
    } catch (_) {}
    _flashOn = false;
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
        _sendSOS();
      }
    });
  }

  Future<void> _startListening() async {
    try {
      bool available = await _speech.initialize(
        onError: (error) {
          if (mounted && _fallAlertActive && error.errorMsg != 'error_busy') {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted && _fallAlertActive) _startListening();
            });
          }
        },
        onStatus: (status) {
          if (status == 'notListening' && mounted) {
            setState(() => _isListening = false);
            if (_fallAlertActive && _secondsRemaining > 0) {
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted && _fallAlertActive) _startListening();
              });
            }
          }
        },
      );

      if (available && mounted && _fallAlertActive) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (result) {
            final words = result.recognizedWords.toLowerCase();
            if (mounted) setState(() => _lastHeardWords = words);
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
      print('Speech init error: $e');
    }
  }

  void _checkForCancelCommand(String words) {
    for (final keyword in _cancelKeywords) {
      if (words.contains(keyword)) {
        _cancelFallAlert();
        return;
      }
    }
  }

  void _cancelFallAlert() {
    if (!_fallAlertActive) return;
    _countdownTimer?.cancel();
    _speech.stop();
    _tts.stop();
    _stopPhoneAlerts();
    _fallDetectionEngine.cancelSOS();
    context.read<FallDetectionProvider>().setFallDetected(false);

    setState(() {
      _fallAlertActive = false;
      _isListening = false;
      _lastHeardWords = '';
    });

    _showDynamicIsland(
      message: 'SOS Cancelled',
      icon: Icons.check_circle,
      color: AnimeColors.successGreen,
    );
  }

  Future<void> _sendSOS() async {
    _speech.stop();
    _stopPhoneAlerts();

    final provider = context.read<FallDetectionProvider>();
    final contacts = provider.emergencyContacts;
    final contactDisplay =
        contacts.isNotEmpty ? contacts.first : 'emergency contacts';

    setState(() {
      _fallAlertActive = false;
      _isListening = false;
    });

    _showDynamicIsland(
      message: 'SOS sent to $contactDisplay',
      icon: Icons.send,
      color: AnimeColors.dangerRed,
      duration: const Duration(seconds: 4),
    );

    _tts.speak('Sending SOS alert now.');
  }

  // ============ Lifecycle ============

  @override
  void dispose() {
    _uiUpdateTimer?.cancel();
    _islandTimer?.cancel();
    _countdownTimer?.cancel();
    _vibrationTimer?.cancel();
    _flashTimer?.cancel();
    _islandAnimController?.dispose();
    _tts.stop();
    _speech.stop();
    try { TorchLight.disableTorch(); } catch (_) {}
    Vibration.cancel();
    _fallDetectionEngine.dispose();
    super.dispose();
  }

  // ============ Build ============

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Double-tap anywhere to cancel SOS (accessibility)
      onDoubleTap: _fallAlertActive ? _cancelFallAlert : null,
      child: Scaffold(
        backgroundColor: AnimeColors.bg,
        floatingActionButton: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'made by CodeBlooded',
              style: TextStyle(
                color: AnimeColors.neonPurple.withOpacity(0.3),
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 12),
            FloatingActionButton(
              onPressed: () => _showProfileMenu(context),
              backgroundColor: AnimeColors.cardBg,
              shape: CircleBorder(
                side: BorderSide(
                  color: AnimeColors.neonPurple.withOpacity(0.4),
                  width: 1.5,
                ),
              ),
              child: Icon(Icons.settings,
                  color: AnimeColors.neonPurple, size: 24),
            ),
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              // Main content
              SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 50),

                    // --- App Name + Toggle ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [
                                AnimeColors.neonPink,
                                AnimeColors.neonPurple,
                              ],
                            ).createShader(bounds),
                            child: Text(
                              'FALLASSIST',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 28,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          const Spacer(),
                          CupertinoSwitch(
                            value: _isDetectionEnabled,
                            activeTrackColor: AnimeColors.neonPurple,
                            thumbColor: Colors.white,
                            onChanged: _fallAlertActive
                                ? null
                                : (value) {
                                    setState(
                                        () => _isDetectionEnabled = value);
                                    final provider = context
                                        .read<FallDetectionProvider>();
                                    if (value) {
                                      _fallDetectionEngine.initialize(
                                        emergencyContact:
                                            provider.emergencyContact,
                                      );
                                      provider.setMonitoring(true);
                                      _showDynamicIsland(
                                        message:
                                            'Smart Fall Detection is ON',
                                        icon: Icons.shield,
                                        color: AnimeColors.successGreen,
                                      );
                                    } else {
                                      _fallDetectionEngine.dispose();
                                      provider.setMonitoring(false);
                                      _showDynamicIsland(
                                        message:
                                            'Smart Fall Detection is OFF',
                                        icon: Icons.shield_outlined,
                                        color: AnimeColors.dangerRed,
                                      );
                                    }
                                  },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- Live Sensor Display ---
                    IntrinsicHeight(
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildSensorCard(
                              title: 'Accelerometer',
                              value:
                                  '${SensorMonitoring.currentAccMag.toStringAsFixed(2)} m/s²',
                              isTriggered:
                                  SensorMonitoring.currentRawAccMag > 12.0,
                              color: AnimeColors.neonCyan,
                              icon: Icons.speed,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSensorCard(
                              title: 'Gyroscope',
                              value:
                                  '${SensorMonitoring.currentGyroMag.toStringAsFixed(2)} rad/s',
                              isTriggered:
                                  SensorMonitoring.currentGyroMag > 2.0,
                              color: AnimeColors.neonPink,
                              icon: Icons.rotate_right,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- Inline Fall Alert Panel ---
                    if (_fallAlertActive) _buildFallAlertPanel(),
                  ],
                ),
              ),

              // --- Dynamic Island ---
              if (_islandVisible && _islandAnimation != null)
                Positioned(
                  top: 8,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: ScaleTransition(
                      scale: _islandAnimation!,
                      child: FadeTransition(
                        opacity: _islandAnimation!,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF1A1A2E),
                                const Color(0xFF16213E),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: _islandColor.withOpacity(0.3),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _islandColor.withOpacity(0.25),
                                blurRadius: 20,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_islandIcon,
                                  color: _islandColor, size: 18),
                              const SizedBox(width: 10),
                              Text(
                                _islandMessage,
                                style: TextStyle(
                                  color: AnimeColors.warmWhite,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ============ Fall Alert Panel Widget ============

  Widget _buildFallAlertPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AnimeColors.dangerRed.withOpacity(0.15),
            AnimeColors.neonPink.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AnimeColors.dangerRed.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: AnimeColors.dangerRed.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning_rounded,
                  color: AnimeColors.dangerRed, size: 24),
              const SizedBox(width: 8),
              Text(
                'FALL DETECTED',
                style: TextStyle(
                  color: AnimeColors.dangerRed,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Countdown
          Text(
            'Sending SOS in',
            style: TextStyle(color: AnimeColors.warmWhite.withOpacity(0.6), fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            '$_secondsRemaining',
            style: TextStyle(
              color: AnimeColors.dangerRed,
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'seconds',
            style: TextStyle(color: AnimeColors.warmWhite.withOpacity(0.6), fontSize: 14),
          ),
          const SizedBox(height: 16),

          // Mic listening
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isListening ? Icons.mic : Icons.mic_off,
                color: _isListening
                    ? AnimeColors.successGreen
                    : AnimeColors.warmWhite.withOpacity(0.3),
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                _isListening ? 'Listening...' : 'Starting mic...',
                style: TextStyle(
                  color: _isListening
                      ? AnimeColors.successGreen
                      : AnimeColors.warmWhite.withOpacity(0.3),
                  fontSize: 13,
                ),
              ),
            ],
          ),

          if (_lastHeardWords.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '"$_lastHeardWords"',
              style: TextStyle(
                color: AnimeColors.warmWhite.withOpacity(0.3),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 16),

          // Cancel instruction
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _cancelFallAlert,
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: AnimeColors.neonPink.withOpacity(0.4)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Double-tap anywhere or say "Stop"',
                style: TextStyle(
                  color: AnimeColors.sakura.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============ Profile Menu ============

  void _showProfileMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AnimeColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AnimeColors.neonPurple.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Icon(Icons.contact_phone,
                      color: AnimeColors.neonCyan),
                  title: Text(
                    'View Emergency Contacts',
                    style: TextStyle(
                        color: AnimeColors.warmWhite, fontSize: 16),
                  ),
                  trailing: Icon(Icons.chevron_right,
                      color: AnimeColors.warmWhite.withOpacity(0.3)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EmergencyContactsScreen(
                          fallDetectionEngine: _fallDetectionEngine,
                          onContactChanged: (String action) {
                            _showDynamicIsland(
                              message: action,
                              icon: Icons.contact_phone,
                              color: AnimeColors.neonCyan,
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============ Sensor Card ============

  Widget _buildSensorCard({
    required String title,
    required String value,
    required bool isTriggered,
    required Color color,
    required IconData icon,
  }) {
    final displayColor = isTriggered ? AnimeColors.dangerRed : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AnimeColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: displayColor.withOpacity(isTriggered ? 0.7 : 0.3),
          width: isTriggered ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: displayColor.withOpacity(0.1),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: displayColor, size: 18),
              const SizedBox(width: 6),
              Text(title,
                  style: TextStyle(
                      fontSize: 12,
                      color: AnimeColors.warmWhite.withOpacity(0.5))),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: displayColor,
            ),
          ),
        ],
      ),
    );
  }
}
