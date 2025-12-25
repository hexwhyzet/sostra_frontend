import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:qr_reader/services/notification_service.dart';
import 'package:qr_reader/universal_safe_area.dart';

import 'firebase_options.dart';
import 'login.dart';

const primaryColor = Color(0xFF006940);

void main() async {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: primaryColor,
      systemNavigationBarColor: primaryColor,
      systemNavigationBarDividerColor: primaryColor,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.light,
    ),
  );

  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Awesome Notifications
  await AwesomeNotifications().initialize(
    null,
    [
      NotificationChannel(
        channelKey: 'basic_channel',
        channelName: 'Basic notifications',
        channelDescription: 'Notification channel for basic notifications',
        defaultColor: primaryColor,
        ledColor: Colors.white,
        importance: NotificationImportance.High,
        channelShowBadge: true,
        playSound: true,
        enableVibration: true,
      ),
    ],
  );

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  // Request notification permissions
  final allowed = await AwesomeNotifications().isNotificationAllowed();
  if (!allowed) {
    await AwesomeNotifications().requestPermissionToSendNotifications();
  }

  // Setup foreground message handler
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    print('Got a message whilst in the foreground!');
    print('Message data: ${message.data}');

    // Use notification payload first, fallback to data payload
    final title = message.notification?.title ?? message.data['title'] ?? 'Уведомление';
    final body = message.notification?.body ?? message.data['body'] ?? '';

    print('Showing notification: $title - $body');

    // Show notification using Awesome Notifications
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch,
        channelKey: 'basic_channel',
        title: title,
        body: body,
        notificationLayout: NotificationLayout.Default,
      ),
    );
  });

  runApp(const FirebasePermissionGate());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final FlexSchemeColor customScheme = FlexSchemeColor.from(primary: primaryColor);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('ru', 'RU'),
      supportedLocales: const [
        Locale('ru', 'RU'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: ThemeMode.light,
      title: 'Sostra',
      theme: FlexThemeData.light(colors: customScheme),
      debugShowCheckedModeBanner: false,
      home: Builder(
        builder: (BuildContext context) {
          return Container(
            color: Theme.of(context).primaryColor,
            child: SafeArea(
              top: true,
              left: false,
              right: false,
              bottom: false,
              child: Container(
                color: Theme.of(context).canvasColor,
                child: SafeArea(
                  top: false,
                  left: false,
                  right: false,
                  bottom: true,
                  child: AuthChecker(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
