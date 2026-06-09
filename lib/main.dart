import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'services/trigger_service.dart';
import 'services/settings_service.dart';
import 'services/notification_service.dart';
import 'services/debug_logger.dart';
import 'services/foreground_task_handler.dart';
import 'services/web_server.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'deadswitch_trigger_v4',
      channelName: 'Dead Switch Active',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(60000),
      autoRunOnBoot: false,
      allowWifiLock: true,
    ),
  );

  FlutterError.onError = (d) {
    runApp(_CrashScreen(error: d.exception, stack: d.stack ?? StackTrace.empty));
  };
  await runZonedGuarded(() async {
    DebugLogger.log('MAIN', 'app starting v1.2.50');
    try {
      await NotificationService.init();
    } catch (e) {
      DebugLogger.log('MAIN', 'NotificationService.init error: $e');
    }
    try {
      if (await SettingsService.webPortalEnabled) {
        await WebServer.start();
      }
    } catch (_) {}
    runApp(const DeadSwitchApp());
  }, (error, stack) {
    DebugLogger.log('CRASH', '$error\n$stack');
    runApp(_CrashScreen(error: error, stack: stack));
  });
}

class _CrashScreen extends StatelessWidget {
  final Object error;
  final StackTrace stack;
  const _CrashScreen({required this.error, required this.stack});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('CRASH REPORT', style: TextStyle(color: Color(0xFFff4444),
                  fontSize: 20, fontWeight: FontWeight.bold)),
              const Text('Long-press text below to copy',
                  style: TextStyle(color: Colors.grey, fontSize: 11)),
              const SizedBox(height: 12),
              SelectableText(error.toString(),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13, fontFamily: 'monospace')),
              const SizedBox(height: 12),
              SelectableText(stack.toString(),
                  style: const TextStyle(
                      color: Color(0xFFaaaaaa), fontSize: 10, fontFamily: 'monospace')),
            ]),
          ),
        ),
      ),
    );
  }
}

class DeadSwitchApp extends StatelessWidget {
  const DeadSwitchApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DeadSwitch',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0f0f0f),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF2563eb),
          surface: Color(0xFF1a1a1a),
        ),
        cardTheme: const CardThemeData(color: Color(0xFF1a1a1a)),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1a1a1a),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF111111),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF333333))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF333333))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF2563eb))),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final has = await SettingsService.hasPin;
    if (!mounted) return;
    Navigator.pushReplacement(context,
        MaterialPageRoute(
            builder: (_) =>
                has ? const LoginScreen() : const LoginScreen(isSetup: true)));
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
