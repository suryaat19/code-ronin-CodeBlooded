import 'dart:math';

/// Real ML fall detector using trained logistic regression model.
/// Model: 12 features, standardized (z-score), sigmoid output.
class MLFallDetector {
  // ===== TRAINED MODEL PARAMETERS =====
  static const List<double> _weights = [
    1.491267878551116,
    -2.989426754569437,
    -10.325931835015773,
    -2.4826821864833417,
    1.8982952510800284,
    -0.13760218193953716,
    -0.9945562809111279,
    0.7899183146455069,
    -0.009865520501231689,
    0.004557534816408199,
    1.051618643458381,
    4.416051560730211,
  ];

  static const double _bias = -0.7934105374498217;

  static const List<double> _mean = [
    15.005025967099682,
    10.20198556902496,
    2.255171781263121,
    6.965789077510973,
    8.039236889588791,
    2.4211670929374223,
    1.0686637188887074,
    0.5124770704771385,
    1.1267953241277637,
    -3.56132672276338e-05,
    0.3411576235944077,
    13941.085102559258,
  ];

  static const List<double> _scale = [
    5.423912136973756,
    0.8569586549417957,
    2.5239831271939233,
    3.0793263172721446,
    8.288223094517347,
    2.5218042113156462,
    1.017673724950461,
    0.5127072440397572,
    1.3928116733440008,
    0.04040819220105031,
    0.3823174374315232,
    3473.8794421603698,
  ];

  static const double _threshold = 0.65;

  /// Sigmoid activation function
  static double _sigmoid(double z) {
    return 1.0 / (1.0 + exp(-z));
  }

  /// Verify fall using the trained logistic regression model.
  ///
  /// [features] must be a list of exactly 12 extracted features:
  ///   0: acc_max    — max accelerometer magnitude in window
  ///   1: acc_mean   — mean accelerometer magnitude
  ///   2: acc_std    — std deviation of accelerometer
  ///   3: acc_min    — min accelerometer magnitude
  ///   4: acc_range  — max - min accelerometer
  ///   5: gyro_max   — max gyroscope magnitude
  ///   6: gyro_mean  — mean gyroscope magnitude
  ///   7: gyro_std   — std deviation of gyroscope
  ///   8: jerk_max   — max jerk (rate of change of acceleration)
  ///   9: jerk_mean  — mean jerk
  ///  10: jerk_std   — std deviation of jerk
  ///  11: energy     — sum of squared acceleration magnitudes
  ///
  /// Returns confidence score 0.0 - 1.0
  static Future<double> verifyFall(List<double> features) async {
    try {
      if (features.length != 12) {
        print('[ML] Invalid feature count: ${features.length}, expected 12');
        return 0.0;
      }

      // Z-score standardization: (x - mean) / scale
      final standardized = List<double>.generate(12, (i) {
        if (_scale[i] == 0) return 0.0;
        return (features[i] - _mean[i]) / _scale[i];
      });

      // Linear combination: w·x + b
      double z = _bias;
      for (int i = 0; i < 12; i++) {
        z += _weights[i] * standardized[i];
      }

      // Sigmoid to get probability
      final confidence = _sigmoid(z);

      print('[ML] Features: [${features.map((f) => f.toStringAsFixed(2)).join(', ')}]');
      print('[ML] Confidence: ${(confidence * 100).toStringAsFixed(1)}% '
          '(threshold: ${(_threshold * 100).toStringAsFixed(0)}%)');

      return confidence;
    } catch (e) {
      print('[ML] Error: $e');
      return 0.0;
    }
  }

  /// Get the model's confidence threshold
  static double get threshold => _threshold;

  /// Load model (no-op since weights are embedded)
  static Future<void> loadModel() async {
    print('[ML] Logistic regression model ready (12 features, embedded weights)');
  }
}
