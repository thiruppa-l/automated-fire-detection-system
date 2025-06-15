// background_service.dart
import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final _databaseRef = FirebaseDatabase.instance.ref();

void onStart() {
  // Initialize the local notifications plugin.
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  // Configure notification settings (Android).
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings =
  InitializationSettings(android: initializationSettingsAndroid);
  flutterLocalNotificationsPlugin.initialize(initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification button actions.
        if (details.payload == "toggleAlarm") {
          // Toggle the alarm state in the database.
          _databaseRef.child("fire_alarm").get().then((snapshot) {
            final currentState =
                (snapshot.value as Map)["isAlarmTriggered"] ?? false;
            _databaseRef.child("fire_alarm").update({
              "isAlarmTriggered": !currentState,
            });
          });
        }
      });

  // Show a persistent notification with an action button.
  Timer.periodic(Duration(seconds: 10), (timer) async {
    // Example: update detected humans from database if needed.
    // In a real app, you’d probably update this value based on a sensor.
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'alarm_channel',
      'Alarm Notifications',
      channelDescription: 'Notifications for fire alarm status',
      importance: Importance.max,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'toggle',
          'Toggle Alarm',
          showsUserInterface: true,
          // you can pass payload to determine action:
          // payload: 'toggleAlarm'
        ),
      ],
    );
    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    // Retrieve the current alarm state and detected humans.
    final snapshot = await _databaseRef.child("fire_alarm").get();
    final data = snapshot.value as Map? ?? {};
    bool isAlarmTriggered = data["isAlarmTriggered"] ?? false;
    int detectedHumans = data["detectedHumans"] ?? 0;

    await flutterLocalNotificationsPlugin.show(
      0,
      "Fire Alarm ${isAlarmTriggered ? 'Active' : 'Inactive'}",
      "Detected Humans: $detectedHumans",
      platformChannelSpecifics,
      payload: "toggleAlarm", // Action payload
    );
  });
}
