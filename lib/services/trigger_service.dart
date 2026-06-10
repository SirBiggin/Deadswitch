import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../db/database.dart';
import 'notification_service.dart';
import 'settings_service.dart';
import 'sms_service.dart';
import 'foreground_task_handler.dart';
import 'debug_logger.dart';

class TriggerService {

  static Timer? _triggerTimer;

  static Future<DateTime> initiate() async {
    _triggerTimer?.cancel();

    final delay  = await SettingsService.delaySeconds;
    final db = await DB.instance;
    final sendAt = DateTime.now().toUtc().add(Duration(seconds: delay));
    DebugLogger.log('TRIGGER', 'initiate delay=${delay}s sendAt=$sendAt');
    await db.update('pending_triggers', {'status': 'cancelled'},
        where: "status = 'pending'");
    await db.insert('pending_triggers', {'send_at': sendAt.toIso8601String()});

    _triggerTimer = Timer(
      Duration(seconds: delay),
      () => _fire(sendAt),
    );

    try {
      if (!await FlutterForegroundTask.isRunningService) {
        FlutterForegroundTask.skipServiceResponseCheck = true;
        await FlutterForegroundTask.startService(
          serviceId: 256,
          notificationTitle: '☠',
          notificationText: ' ',
          callback: startDeadSwitchCallback,
        );
        FlutterForegroundTask.skipServiceResponseCheck = false;
      } else {
        await FlutterForegroundTask.updateService(
          notificationTitle: '☠',
          notificationText: ' ',
        );
      }
    } catch (e) {
      DebugLogger.log('TRIGGER', 'foreground service error: $e');
    }

    return sendAt.toLocal();
  }

  static Future<void> _fire(DateTime sendAt) async {
    try {
      final db  = await DB.instance;
      final due = await db.query('pending_triggers',
          where: "status = 'pending' AND send_at <= ?",
          whereArgs: [DateTime.now().toUtc().toIso8601String()]);
      for (final row in due) {
        try {
          final results = await SmsService.sendAllMessages();
          final anyFailed = results.any((r) => r['status'] != 'sent');
          for (final r in results) DebugLogger.log('SMS', '${r["contact"]}: ${r["status"]} ${r["detail"] ?? ""}');
          await db.update('pending_triggers', {'status': 'success'},
              where: 'id = ?', whereArgs: [row['id']]);
          await db.insert('trigger_log',
              {'status': anyFailed ? 'partial' : 'success'});
          DebugLogger.log('TRIGGER', '_fire done anyFailed=$anyFailed');
        } catch (e) {
          DebugLogger.log('TRIGGER', '_fire sms error: $e');
          await db.update('pending_triggers', {'status': 'error'},
              where: 'id = ?', whereArgs: [row['id']]);
          await db.insert('trigger_log', {'status': 'timer_error: $e'});
        }
      }
      try { await FlutterForegroundTask.stopService(); } catch (_) {}
      await NotificationService.cancelCountdown();
    } catch (e) {
      DebugLogger.log('TRIGGER', '_fire crash: $e');
      try {
        final db = await DB.instance;
        await db.insert('trigger_log', {'status': 'timer_crash: $e'});
      } catch (_) {}
    }
  }

  static Future<void> abort() async {
    DebugLogger.log('TRIGGER', 'abort called');
    _triggerTimer?.cancel();
    _triggerTimer = null;
    final db = await DB.instance;
    await db.update('pending_triggers', {'status': 'cancelled'},
        where: "status = 'pending'");
    try { await FlutterForegroundTask.stopService(); } catch (_) {}
    await NotificationService.cancelCountdown();
  }

  static Future<DateTime?> pendingSendAt() async {
    final db   = await DB.instance;
    final rows = await db.query('pending_triggers',
        where: "status = 'pending'", orderBy: 'id ASC', limit: 1);
    if (rows.isEmpty) return null;
    return DateTime.parse(rows.first['send_at'] as String).toLocal();
  }
}
