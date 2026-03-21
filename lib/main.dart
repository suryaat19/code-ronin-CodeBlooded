import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'screens/main_dashboard.dart';
import 'screens/pre_alarm_screen.dart';
import 'providers/fall_detection_provider.dart';
import 'services/background_service.dart';
import 'services/background_imu_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notifications first (required for background fall alerts)
  await NotificationService.initializeNotifications();

  // Initialize background IMU service
  await BackgroundIMUService.initializeService();

  // Start the background service
  startBackgroundService();

  runApp(const FallSenseApp());
}

class FallSenseApp extends StatefulWidget {
  const FallSenseApp({Key? key}) : super(key: key);

  @override
  State<FallSenseApp> createState() => _FallSenseAppState();
}

class _FallSenseAppState extends State<FallSenseApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _setupBackgroundFallDetectionListener();
  }

  /// Listen for fall detection events from background service
  void _setupBackgroundFallDetectionListener() {
    final service = FlutterBackgroundService();

    // Listen for fall detection from background service
    service.on('fallDetected').listen((event) {
      print('🚨 MAIN: Fall detection received from background service');
      _showFallAlert();
    });

    // Listen for show alert command
    service.on('showFallAlert').listen((event) {
      print('🚨 MAIN: Show fall alert command received');
      _showFallAlert();
    });

    print('✅ Background fall detection listener set up');
  }

  /// Show fall alert screen and notification
  void _showFallAlert() {
    // Show notification
    NotificationService.showFallDetectionAlert();

    // Navigate to PreAlarmScreen if not already there
    final currentRoute = _navigatorKey.currentState?.widget.runtimeType.toString();
    if (currentRoute != 'PreAlarmScreen') {
      _navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/pre-alarm',
        (route) => route.settings.name == '/',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FallDetectionProvider()),
      ],
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'FallSense MVP',
        theme: ThemeData(
          primarySwatch: Colors.green,
          useMaterial3: true,
        ),
        onGenerateRoute: (RouteSettings settings) {
          switch (settings.name) {
            case '/pre-alarm':
              return MaterialPageRoute(
                builder: (context) => const PreAlarmScreen(),
                settings: const RouteSettings(name: 'PreAlarmScreen'),
              );
            default:
              return MaterialPageRoute(
                builder: (context) => const MainDashboard(),
              );
          }
        },
        home: const MainDashboard(),
      ),
    );
  }
}
