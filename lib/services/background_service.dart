import 'dart:isolate';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

final ReceivePort port = ReceivePort();

void startBackgroundService() async {
  final service = FlutterBackgroundService();
  
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: true,
    ),
    iosConfiguration: IosConfiguration(
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );

  service.startService();
}

// This will be run by the native platform
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  
  DartPluginRegistrant.ensureInitialized();

  
  Timer.periodic(const Duration(seconds: 2), (timer) {
    print('Background Service Running: ${DateTime.now()}');
  });

  service.on('stopService').listen((event) {
    service.stopSelf();
  });
}

// For iOS
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  Timer.periodic(const Duration(seconds: 2), (timer) {
    print('iOS Background Service Running: ${DateTime.now()}');
  });

  return true;
}
