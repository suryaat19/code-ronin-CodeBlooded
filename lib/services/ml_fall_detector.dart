import 'dart:isolate';
import 'package:flutter/services.dart';

class MLFallDetector {
  static const String MODEL_PATH = 'assets/models/fall_detection_model.tflite';
  
  // For now, we'll use a mock implementation
  // In production, load actual TFLite model here
  
  /// Load the TFLite model
  static Future<void> loadModel() async {
    try {
      // In production, use tflite_flutter to load the model
      // For MVP, we'll mock this
      print('ML Model loaded (mock)');
    } catch (e) {
      print('Error loading ML model: $e');
    }
  }

  /// Verify fall using ML model
  /// Input: 2-second window of sensor data (accelerometer + gyroscope)
  /// Output: confidence score 0.0-1.0
  static Future<double> verifyFall(List<double> sensorWindow) async {
    try {
      // Mock ML verification for MVP Phase 1
      // In production, this would:
      // 1. Preprocess sensor data
      // 2. Run through tflite_flutter interpreter
      // 3. Return confidence score
      
      // Simple heuristic: if data shows fall pattern, return high confidence
      if (sensorWindow.isEmpty) return 0.0;
      
      double maxAccel = sensorWindow.reduce((a, b) => a > b ? a : b);
      double mean = sensorWindow.reduce((a, b) => a + b) / sensorWindow.length;
      
      // Mock confidence: higher if peak is significantly above mean
      double confidence = ((maxAccel - mean) / 5.0).clamp(0.0, 1.0);
      
      print('ML Verification - Confidence: ${(confidence * 100).toStringAsFixed(2)}%');
      return confidence;
    } catch (e) {
      print('Error in ML verification: $e');
      return 0.0;
    }
  }

  /// Run ML verification asynchronously
  static Future<void> verifyFallAsync(
    List<double> sensorWindow,
    SendPort sendPort,
  ) async {
    final confidence = await verifyFall(sensorWindow);
    sendPort.send(confidence);
  }
}

class IsolateCommunication {
  static ReceivePort? _mainReceivePort;
  static SendPort? _backgroundSendPort;

  /// Initialize communication between main and background isolate
  static Future<void> initialize() async {
    _mainReceivePort = ReceivePort();
    
    _mainReceivePort?.listen((message) {
      if (message is double) {
        // This is ML confidence from background isolate
        print('Received ML confidence from background: $message');
        _handleMLResult(message);
      } else if (message is String && message == 'FALL_DETECTED') {
        print('Fall detection confirmed from background isolate');
        _handleFallDetected();
      }
    });
  }

  /// Send data to background isolate
  static void sendToBackground(String message) {
    if (_backgroundSendPort != null) {
      _backgroundSendPort?.send(message);
    } else {
      print('Background send port not initialized');
    }
  }

  /// Register background send port (called from background isolate)
  static void registerBackgroundPort(SendPort sendPort) {
    _backgroundSendPort = sendPort;
    print('Background isolate port registered');
  }

  /// Handle ML verification result
  static void _handleMLResult(double confidence) {
    // If confidence > 0.7, consider it a confirmed fall
    if (confidence > 0.7) {
      _handleFallDetected();
    } else {
      print('Fall not confirmed - confidence too low: $confidence');
    }
  }

  /// Handle confirmed fall - trigger PreAlarmScreen
  static void _handleFallDetected() {
    // This will be called from the main isolate
    // The navigation will be handled by a callback in the app state
    print('FALL DETECTED AND CONFIRMED');
  }

  /// Cleanup
  static void dispose() {
    _mainReceivePort?.close();
  }
}
