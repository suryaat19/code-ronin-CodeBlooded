import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fallsense_app/screens/pre_alarm_screen.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';

class NotificationService {
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Initialize notifications
  static Future<void> initializeNotifications() async {
    // Android initialization
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      onDidReceiveLocalNotification: (id, title, body, payload) async {
        // Handle notification tap on iOS
        print('📱 iOS Notification received: $title - $body');
      },
    );

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        print('🔔 Notification tapped: ${response.payload}');
        // Handle notification tap - will be processed by main app
      },
    );

    print('✅ NotificationService initialized');
  }

  // Show high-priority fall detection alert notification
  static Future<void> showFallDetectionAlert() async {
    final androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'fall_detection_channel',
      'Fall Detection Alerts',
      channelDescription: 'Alerts for detected fall events',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      autoCancel: false,
      enableVibration: true,
      enableLights: true,
      vibrationPattern: Int64List.fromList([0, 500, 500, 500]),
      ticker: 'fall_detected',
      ongoing: true,
      playSound: true,
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'ok_action',
          'I\'m OK',
          cancelNotification: true,
        ),
        const AndroidNotificationAction(
          'help_action',
          'Send SOS',
          cancelNotification: false,
        ),
      ],
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      badgeNumber: 1,
      threadIdentifier: 'fall_detection',
    );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      '🚨 FALL DETECTED',
      'You may have fallen. Tap to respond.',
      platformChannelSpecifics,
      payload: 'fall_detected',
    );

    print('🚨 Fall detection alert notification sent');
  }

  // Cancel notification
  static Future<void> cancelNotification() async {
    await flutterLocalNotificationsPlugin.cancel(0);
    print('🔕 Notification cancelled');
  }

  // Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
    print('🔕 All notifications cancelled');
  }
}
