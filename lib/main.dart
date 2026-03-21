import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/main_dashboard.dart';
import 'providers/fall_detection_provider.dart';
import 'services/background_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  startBackgroundService();
  runApp(const FallSenseApp());
}

class FallSenseApp extends StatelessWidget {
  const FallSenseApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FallDetectionProvider()),
      ],
      child: MaterialApp(
        title: 'FallSense MVP',
        theme: ThemeData(
          primarySwatch: Colors.green,
          useMaterial3: true,
        ),
        home: const MainDashboard(),
      ),
    );
  }
}
