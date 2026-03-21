import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/fall_detection_provider.dart';
import '../services/fall_detection_engine.dart';
import 'pre_alarm_screen.dart';

class MainDashboard extends StatefulWidget {
  const MainDashboard({Key? key}) : super(key: key);

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  late FallDetectionEngine _fallDetectionEngine;

  @override
  void initState() {
    super.initState();
    _initializeFallDetection();
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
    _fallDetectionEngine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status text with high contrast
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
              const SizedBox(height: 40),
              // Emergency contacts display
              Consumer<FallDetectionProvider>(
                builder: (context, provider, _) {
                  final contacts = provider.emergencyContacts;
                  return Semantics(
                    label: contacts.isNotEmpty
                        ? 'Emergency contacts: ${contacts.join(", ")}'
                        : 'No emergency contacts set',
                    enabled: true,
                    child: Column(
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
                                        child: Padding(
                                          padding: const EdgeInsets.only(left: 8.0),
                                          child: Icon(
                                            Icons.close,
                                            color: Colors.red,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 60),
              // Large, tappable button for adding emergency contact
              Semantics(
                button: true,
                onTap: () => _showEmergencyContactDialog(context),
                label: 'Add Emergency Contact',
                enabled: true,
                child: ElevatedButton(
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
              ),
              const SizedBox(height: 20),
              // Monitoring indicator
              Consumer<FallDetectionProvider>(
                builder: (context, provider, _) {
                  return Semantics(
                    label: provider.isMonitoring
                        ? 'System is actively monitoring'
                        : 'System is not monitoring',
                    enabled: true,
                    child: Text(
                      provider.isMonitoring
                          ? '✓ Monitoring Active'
                          : '✗ Monitoring Inactive',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: provider.isMonitoring
                            ? Colors.green
                            : Colors.red,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEmergencyContactDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Emergency Contact'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            hintText: 'Enter phone number',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                final provider = context.read<FallDetectionProvider>();
                provider.addEmergencyContact(controller.text);
                _fallDetectionEngine.addEmergencyContact(controller.text);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Contact added: ${controller.text}')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
