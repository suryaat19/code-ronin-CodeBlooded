import 'package:flutter/material.dart';

class FallDetectionProvider extends ChangeNotifier {
  List<String> _emergencyContacts = [];
  bool _isMonitoring = false;
  bool _fallDetected = false;

  List<String> get emergencyContacts => List.unmodifiable(_emergencyContacts);
  String? get emergencyContact => _emergencyContacts.isNotEmpty ? _emergencyContacts.first : null;
  bool get isMonitoring => _isMonitoring;
  bool get fallDetected => _fallDetected;

  void setEmergencyContact(String contact) {
    if (!_emergencyContacts.contains(contact)) {
      _emergencyContacts.add(contact);
      notifyListeners();
    }
  }

  void addEmergencyContact(String contact) {
    if (contact.isNotEmpty && !_emergencyContacts.contains(contact)) {
      _emergencyContacts.add(contact);
      notifyListeners();
    }
  }

  void removeEmergencyContact(String contact) {
    _emergencyContacts.remove(contact);
    notifyListeners();
  }

  void setMonitoring(bool monitoring) {
    _isMonitoring = monitoring;
    notifyListeners();
  }

  void setFallDetected(bool detected) {
    _fallDetected = detected;
    notifyListeners();
  }
}
