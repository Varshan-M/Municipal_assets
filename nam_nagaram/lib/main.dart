import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'package:go_router/go_router.dart';
import 'firebase_options.dart';

void _handleNotificationClick(Map<String, dynamic> data) {
  final complaintId = data['complaintId'];
  if (complaintId != null && rootNavigatorKey.currentContext != null) {
    rootNavigatorKey.currentContext!.push('/report-detail/$complaintId');
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Note: The user needs to run `flutterfire configure` to generate `firebase_options.dart`.
  // If the file is missing, the app will fail to compile. I'm importing it assuming the user
  // will perform this step as described in the verification plan.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('Firebase initialization failed (did you run flutterfire configure?): $e');
  }

  // Request notification permissions for foreground notifications
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // Initialize flutter_local_notifications for foreground notifications
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(
    settings: initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      if (response.payload != null) {
        _handleNotificationClick({'complaintId': response.payload});
      }
    },
  );
  // Create High Importance channel
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel', // id
    'High Importance Notifications', // title
    description: 'This channel is used for important notifications.', // description
    importance: Importance.max,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // Request explicit Android OS notification permission
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();

  // Handle notification tap when the app is in the background
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    _handleNotificationClick(message.data);
  });

  // Handle notification tap when the app was completely terminated
  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    // We delay slightly to ensure the router is fully initialized before pushing
    Future.delayed(const Duration(milliseconds: 500), () {
      _handleNotificationClick(initialMessage.data);
    });
  }

  // Listen to foreground messages and show native OS notification
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint("====================================");
    debugPrint("🔥 FOREGROUND NOTIFICATION RECEIVED! 🔥");
    debugPrint("Title: ${message.notification?.title}");
    debugPrint("Body: ${message.notification?.body}");
    debugPrint("====================================");

    final notification = message.notification;

    if (notification != null) {
      flutterLocalNotificationsPlugin.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        payload: message.data['complaintId'],
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            icon: '@mipmap/ic_launcher',
            importance: Importance.max,
            priority: Priority.max,
            enableVibration: true,
          ),
        ),
      );
    }
  });

  runApp(
    const ProviderScope(
      child: CivicCareApp(),
    ),
  );
}

class CivicCareApp extends ConsumerWidget {
  const CivicCareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    return OverlaySupport.global(
      child: MaterialApp.router(
        title: 'Nam Nagaram',
        theme: AppTheme.lightTheme,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
