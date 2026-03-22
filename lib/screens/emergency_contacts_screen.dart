import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/fall_detection_provider.dart';
import '../services/fall_detection_engine.dart';

class EmergencyContactsScreen extends StatelessWidget {
  final FallDetectionEngine? fallDetectionEngine;
  final void Function(String action)? onContactChanged;

  const EmergencyContactsScreen({
    Key? key,
    this.fallDetectionEngine,
    this.onContactChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Emergency Contacts',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer<FallDetectionProvider>(
        builder: (context, provider, _) {
          final contacts = provider.emergencyContacts;
          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- Contact Count ---
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.people, color: Colors.green, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        'Total Contacts: ${contacts.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // --- Contacts List ---
                Expanded(
                  child: contacts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.contact_phone_outlined,
                                  color: Colors.white24, size: 64),
                              const SizedBox(height: 16),
                              Text(
                                'No emergency contacts added yet.',
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap the button below to add one.',
                                style: TextStyle(
                                    color: Colors.white38, fontSize: 14),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: contacts.length,
                          itemBuilder: (context, index) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.grey[900],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor:
                                        Colors.green.withOpacity(0.2),
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      contacts[index],
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: Colors.red, size: 22),
                                    onPressed: () {
                                      final contact = contacts[index];
                                      provider.removeEmergencyContact(contact);
                                      onContactChanged?.call('Contact removed');
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                'Contact removed: $contact')),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),

                // --- Add Contact Button ---
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () =>
                      _showEmergencyContactDialog(context, provider),
                  icon: const Icon(Icons.person_add, color: Colors.black),
                  label: const Text(
                    'Add Emergency Contact',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showEmergencyContactDialog(
      BuildContext context, FallDetectionProvider provider) {
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
                    child:
                        Text(c['country']!, style: const TextStyle(fontSize: 14)),
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
                provider.addEmergencyContact(fullNumber);
                fallDetectionEngine?.addEmergencyContact(fullNumber);
                onContactChanged?.call('Contact added: $fullNumber');
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
