import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../providers/fall_detection_provider.dart';
import '../services/fall_detection_engine.dart';
import '../services/sensor_monitoring.dart';
import 'pre_alarm_screen.dart';
import 'advanced_fall_detector.dart';

class MainDashboard extends StatefulWidget {
  const MainDashboard({Key? key}) : super(key: key);

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  late FallDetectionEngine _fallDetectionEngine;
  Timer? _uiUpdateTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFallDetection();
    });
  }

  void _initializeFallDetection() {
    final provider = context.read<FallDetectionProvider>();

    _fallDetectionEngine = FallDetectionEngine(
      onFallDetected: (detected) {
        if (detected) {
          provider.setFallDetected(true);
          _showPreAlarmScreen();
        }
      },
    );

    _fallDetectionEngine.initialize(
      emergencyContact: provider.emergencyContact,
    );

    provider.setMonitoring(true);

    // Update UI with live sensor data every 100ms
    _uiUpdateTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) setState(() {});
    });
  }

  void _showPreAlarmScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PreAlarmScreen(
          onCancel: () {
            _fallDetectionEngine.cancelSOS();
            context.read<FallDetectionProvider>().setFallDetected(false);
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _uiUpdateTimer?.cancel();
    _fallDetectionEngine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              // --- Status Header ---
              Semantics(
                label: 'System Status: Active and Monitoring',
                enabled: true,
                child: Text(
                  'System Active & Monitoring',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 28,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // --- Live Sensor Display ---
              _buildSensorCard(
                title: 'Accelerometer',
                value: '${SensorMonitoring.currentAccMag.toStringAsFixed(2)} m/s2',
                rawValue: 'Raw: ${SensorMonitoring.currentRawAccMag.toStringAsFixed(2)}',
                isTriggered: SensorMonitoring.currentRawAccMag > 12.0,
                color: Colors.blue,
                icon: Icons.speed,
              ),
              const SizedBox(height: 12),
              _buildSensorCard(
                title: 'Gyroscope',
                value: '${SensorMonitoring.currentGyroMag.toStringAsFixed(2)} rad/s',
                rawValue: null,
                isTriggered: SensorMonitoring.currentGyroMag > 2.0,
                color: Colors.orange,
                icon: Icons.rotate_right,
              ),
              const SizedBox(height: 12),

              // --- Detection Phase ---
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: SensorMonitoring.currentPhase.contains('Free-fall')
                        ? Colors.yellow
                        : SensorMonitoring.currentPhase.contains('inactivity')
                            ? Colors.orange
                            : Colors.white24,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      SensorMonitoring.currentPhase == 'Monitoring'
                          ? Icons.shield
                          : Icons.warning_amber,
                      color: SensorMonitoring.currentPhase == 'Monitoring'
                          ? Colors.green
                          : Colors.yellow,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      SensorMonitoring.currentPhase,
                      style: TextStyle(
                        fontSize: 16,
                        color: SensorMonitoring.currentPhase == 'Monitoring'
                            ? Colors.white70
                            : Colors.yellow,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // --- Emergency Contacts ---
              Consumer<FallDetectionProvider>(
                builder: (context, provider, _) {
                  final contacts = provider.emergencyContacts;
                  return Column(
                    children: [
                      Text(
                        'Emergency Contacts',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (contacts.isEmpty)
                        Text(
                          'No emergency contacts set yet.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white54,
                            fontSize: 14,
                          ),
                        )
                      else
                        Container(
                          constraints: const BoxConstraints(maxHeight: 150),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: contacts.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${index + 1}. ${contacts[index]}',
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: Colors.white70,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        provider.removeEmergencyContact(contacts[index]);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Contact removed: ${contacts[index]}')),
                                        );
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.only(left: 8.0),
                                        child: Icon(Icons.close, color: Colors.red, size: 18),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 30),

              // --- Add Contact Button ---
              ElevatedButton(
                onPressed: () => _showEmergencyContactDialog(context),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Add Emergency Contact',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // --- Monitoring Indicator ---
              Consumer<FallDetectionProvider>(
                builder: (context, provider, _) {
                  return Text(
                    provider.isMonitoring ? 'Monitoring Active' : 'Monitoring Inactive',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: provider.isMonitoring ? Colors.green : Colors.red,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSensorCard({
    required String title,
    required String value,
    required String? rawValue,
    required bool isTriggered,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTriggered ? Colors.red : color.withOpacity(0.5),
          width: isTriggered ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: isTriggered ? Colors.red : color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isTriggered ? Colors.red : color,
                  ),
                ),
                if (rawValue != null)
                  Text(rawValue, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEmergencyContactDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    String? errorText;
    String selectedCountryCode = '+91';

    final countryCodes = [
      {'code': '+91', 'country': 'India (+91)'},
      {'code': '+1', 'country': 'USA (+1)'},
      {'code': '+44', 'country': 'UK (+44)'},
      {'code': '+61', 'country': 'Australia (+61)'},
      {'code': '+971', 'country': 'UAE (+971)'},
      {'code': '+65', 'country': 'Singapore (+65)'},
      {'code': '+81', 'country': 'Japan (+81)'},
      {'code': '+49', 'country': 'Germany (+49)'},
      {'code': '+33', 'country': 'France (+33)'},
      {'code': '+86', 'country': 'China (+86)'},
    ];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Add Emergency Contact'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedCountryCode,
                decoration: const InputDecoration(
                  labelText: 'Country',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.flag),
                ),
                items: countryCodes.map((c) {
                  return DropdownMenuItem<String>(
                    value: c['code'],
                    child: Text(c['country']!, style: const TextStyle(fontSize: 14)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selectedCountryCode = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  hintText: 'Enter 10-digit phone number',
                  border: const OutlineInputBorder(),
                  errorText: errorText,
                  counterText: '',
                  prefixIcon: const Icon(Icons.phone),
                  prefixText: '$selectedCountryCode ',
                ),
                onChanged: (_) {
                  if (errorText != null) {
                    setDialogState(() => errorText = null);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final number = controller.text.trim();
                if (number.length != 10) {
                  setDialogState(() {
                    errorText = 'Please enter exactly 10 digits';
                  });
                  return;
                }

                final fullNumber = '$selectedCountryCode$number';
                final provider = context.read<FallDetectionProvider>();
                provider.addEmergencyContact(fullNumber);
                _fallDetectionEngine.addEmergencyContact(fullNumber);
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Contact added: $fullNumber')),
                );
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}
