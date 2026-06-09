import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static const _channelId = 'deadswitch_countdown_v6';
  static const _notifId = 42;
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _plugin.initialize(const InitializationSettings(android: androidSettings));
      _initialized = true;
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
    } catch (_) {}
  }

  static Future<void> showCountdown(DateTime sendAt) async {
    try {
      await init();
      final details = AndroidNotificationDetails(
        _channelId,
        'Dead Switch Countdown',
        channelDescription: 'Active dead switch countdown timer',
        importance: Importance.high,
        priority: Priority.high,
        ongoing: true,
        autoCancel: false,
        onlyAlertOnce: true,
        showWhen: true,
        when: sendAt.millisecondsSinceEpoch,
        usesChronometer: true,
        chronometerCountDown: true,
        visibility: NotificationVisibility.public,
      );
      await _plugin.show(
        _notifId,
        '☠',
        ' ',
        NotificationDetails(android: details),
      );
    } catch (_) {}
  }

  static Future<void> cancelCountdown() async {
    try {
      await init();
      await _plugin.cancelAll();
    } catch (_) {}
  }
}
