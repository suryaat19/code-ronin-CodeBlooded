import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import 'sensor_monitoring.dart';
import 'ml_fall_detector.dart';
import 'sms_location_service.dart';
import 'emergency_service.dart';

class FallDetectionEngine {
  final Function(bool) onFallDetected;
  late Timer _sosTimer;
  bool _fallConfirmed = false;
  List<String> _emergencyContacts = [];
  Map<String, String> _contactNames = {}; // Map phone to contact name

  FallDetectionEngine({
    required this.onFallDetected,
  });

  /// Initialize the complete fall detection system
  void initialize({required String? emergencyContact}) {
    if (emergencyContact != null) {
      _emergencyContacts = [emergencyContact];
      _contactNames[emergencyContact] = 'Primary Contact';
    }
    
    // Initialize emergency service (permissions, etc)
    EmergencyService.initialize();
    
    // Start sensor monitoring with callback
    SensorMonitoring.startMonitoring(
      onFallDetected: (detected) {
        if (detected) {
          _handlePotentialFall();
        }
      },
    );

    print('Fall Detection Engine initialized');
  }

  /// Handle when sensors detect a potential fall
  Future<void> _handlePotentialFall() async {
    if (_fallConfirmed) return; // Already processing

    print('Potential fall detected - initiating verification...');

    // Phase 2: ML Verification
    // In a real scenario, we'd pass the sensor buffer to the ML model
    final mockSensorWindow = List<double>.generate(100, (_) => 2.5 + ((_ % 10) * 0.1));
    
    final confidence = await _verifyWithML(mockSensorWindow);

    if (confidence > 0.7) {
      _fallConfirmed = true;
      _onFallConfirmed();
    } else {
      print('Fall not confirmed by ML verification');
    }
  }

  /// Run ML verification on sensor data
  Future<double> _verifyWithML(List<double> sensorWindow) async {
    return await MLFallDetector.verifyFall(sensorWindow);
  }

  /// Handle confirmed fall
  void _onFallConfirmed() {
    print('Fall confirmed! Triggering Pre-Alarm screen...');
    onFallDetected(true);
    _startSOSCountdown();
  }

  /// Start the 15-second SOS countdown
  void _startSOSCountdown() {
    _sosTimer = Timer(const Duration(seconds: 15), _sendSOS);
    print('SOS countdown started - 15 seconds');
  }

  /// Cancel the SOS alert
  void cancelSOS() {
    if (_sosTimer.isActive) {
      _sosTimer.cancel();
      _fallConfirmed = false;
      print('SOS alert cancelled');
    }
  }

  /// Send the actual SOS message with emergency call to respective contacts
  Future<void> _sendSOS() async {
    if (_emergencyContacts.isEmpty) {
      print('❌ No emergency contacts set - cannot send SOS');
      return;
    }

    print('\n🚨 === EMERGENCY PROTOCOL ACTIVATED === 🚨\n');
    print('📞 Emergency contacts to notify: ${_emergencyContacts.length}');

    // Get current location once
    final location = await EmergencyService.getCurrentLocation();

    // Step 1: Send SMS to all contacts first
    print('\n📨 Step 1: Sending emergency SMS to all contacts...\n');
    for (int i = 0; i < _emergencyContacts.length; i++) {
      final contact = _emergencyContacts[i];
      final contactName = _contactNames[contact] ?? 'Emergency Contact';
      
      print('[$i+1/${_emergencyContacts.length}] Sending SMS to $contactName: $contact');
      
      await EmergencyService.sendEmergencySMS(
        phoneNumber: contact,
        message: '🆘 FALL DETECTED - I need help! This is an automated alert from FallSense.',
        location: location,
      );

      // Add delay between SMS to avoid rate limiting
      if (i < _emergencyContacts.length - 1) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    // Step 2: Call primary contact (first in list) with high priority
    if (_emergencyContacts.isNotEmpty) {
      final primaryContact = _emergencyContacts[0];
      final primaryName = _contactNames[primaryContact] ?? 'Primary Contact';
      
      print('\n📞 Step 2: Calling PRIMARY contact...');
      print('   Name: $primaryName');
      print('   Number: $primaryContact\n');
      
      await Future.delayed(const Duration(seconds: 1));
      final callSuccess = await EmergencyService.makeEmergencyCall(primaryContact);
      
      if (callSuccess) {
        print('✅ Emergency call initiated to $primaryName ($primaryContact)');
      } else {
        print('⚠️  Failed to initiate call to $primaryName, trying next contact...');
        
        // If primary call fails, try secondary contact
        if (_emergencyContacts.length > 1) {
          final secondaryContact = _emergencyContacts[1];
          final secondaryName = _contactNames[secondaryContact] ?? 'Secondary Contact';
          
          print('📞 Attempting call to SECONDARY contact...');
          print('   Name: $secondaryName');
          print('   Number: $secondaryContact\n');
          
          await EmergencyService.makeEmergencyCall(secondaryContact);
        }
      }
    }

    print('\n✅ Emergency SOS protocol completed');
    _fallConfirmed = false;
  }

  /// Cleanup
  void dispose() {
    SensorMonitoring.stopMonitoring();
    cancelSOS();
    print('Fall Detection Engine disposed');
  }

  /// Update emergency contact
  void updateEmergencyContact(String contact) {
    _emergencyContacts = [contact];
    print('Emergency contact updated: $contact');
  }

  /// Add emergency contact with name
  void addEmergencyContact(String contact, {String? contactName}) {
    if (!_emergencyContacts.contains(contact)) {
      _emergencyContacts.add(contact);
      _contactNames[contact] = contactName ?? 'Emergency Contact';
      print('Emergency contact added: $contact (${_contactNames[contact]})');
    }
  }

  /// Remove emergency contact
  void removeEmergencyContact(String contact) {
    _emergencyContacts.remove(contact);
    _contactNames.remove(contact);
    print('Emergency contact removed: $contact');
  }
}

