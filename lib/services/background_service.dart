import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

@pragma('vm:entry-point')
class BackgroundService {
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    // Create notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'foreground_service_channel',
      'Talkify Online Status',
      description: 'Maintains your online status to receive calls.',
      importance: Importance.high,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'foreground_service_channel',
        initialNotificationTitle: 'Talkify Online',
        initialNotificationContent: 'App is running in background',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    service.startService();
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Firebase in the background isolate
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        debugPrint("Firebase initialized in background isolate");
      }
    } catch (e) {
      debugPrint("Failed to initialize Firebase in background: $e");
      // If we can't initialize Firebase, we can't continue with background tasks
      return;
    }

    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // Start real-time call monitoring in background isolate
    StreamSubscription? callSubscription;
    
    // Periodically ensure we are authenticated and listening
    Timer.periodic(const Duration(minutes: 5), (timer) async {
       // Presence heartbeat
       try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
            'isOnline': true,
            'lastSeen': FieldValue.serverTimestamp(),
          });
        }
      } catch (_) {}
    });

    // Setup the call listener
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      callSubscription = FirebaseFirestore.instance
          .collection('calls')
          .where('receiverId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'ringing')
          .snapshots()
          .listen((snapshot) {
            if (snapshot.docs.isNotEmpty) {
              final callData = snapshot.docs.first.data();
              flutterLocalNotificationsPlugin.show(
                999,
                'Incoming Call',
                '${callData['callerName']} is calling you',
                const NotificationDetails(
                  android: AndroidNotificationDetails(
                    'high_importance_channel',
                    'High Importance Notifications',
                    importance: Importance.max,
                    priority: Priority.high,
                    fullScreenIntent: true,
                    ongoing: true,
                    styleInformation: BigTextStyleInformation(''),
                  ),
                ),
              );
            }
          });
    }

    service.on('stopService').listen((event) {
      callSubscription?.cancel();
      service.stopSelf();
    });
  }
}
