import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../db/database.dart';
import 'sms_service.dart';
import 'debug_logger.dart';

@pragma('vm:entry-point')
void startDeadSwitchCallback() {
  FlutterForegroundTask.setTaskHandler(DeadSwitchTaskHandler());
}

class DeadSwitchTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    DebugLogger.log('FG', 'service started starter=$starter');
    try {
      final db = await DB.instance;
      await db.insert('trigger_log', {'status': 'fg_started'});
    } catch (e) {
      DebugLogger.log('FG', 'onStart db error: $e');
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _checkAndFire(timestamp);
  }

  Future<void> _checkAndFire(DateTime now) async {
    try {
      final db = await DB.instance;
      final due = await db.query('pending_triggers',
          where: "status = 'pending' AND send_at <= ?",
          whereArgs: [now.toUtc().toIso8601String()]);

      if (due.isEmpty) {
        final pending = await db.query('pending_triggers',
            where: "status = 'pending'", orderBy: 'send_at ASC', limit: 1);
        if (pending.isEmpty) {
          await FlutterForegroundTask.stopService();
        } else {
          final sendAt =
              DateTime.parse(pending.first['send_at'] as String).toUtc();
          final remaining = sendAt.difference(now.toUtc());
          if (!remaining.isNegative) {
            final m = remaining.inMinutes + 1;
            await FlutterForegroundTask.updateService(
              notificationTitle: '☠  Dead Switch Active',
              notificationText: 'Sending in ~${m}m — tap to abort',
            );
          }
        }
        return;
      }

      for (final row in due) {
        try {
          final results = await SmsService.sendAllMessages();
          final anyFailed = results.any((r) => r['status'] != 'sent');
          for (final r in results) DebugLogger.log('SMS', 'fg: ${r["contact"]}: ${r["status"]} ${r["detail"] ?? ""}');
          await db.update('pending_triggers', {'status': 'success'},
              where: 'id = ?', whereArgs: [row['id']]);
          await db.insert('trigger_log',
              {'status': anyFailed ? 'partial' : 'success'});
          DebugLogger.log('FG', 'fire done anyFailed=$anyFailed');
        } catch (e) {
          DebugLogger.log('FG', 'fire sms error: $e');
          await db.update('pending_triggers', {'status': 'error'},
              where: 'id = ?', whereArgs: [row['id']]);
          await db.insert('trigger_log', {'status': 'error: $e'});
        }
      }
      await FlutterForegroundTask.stopService();
    } catch (e) {
      DebugLogger.log('FG', 'crash: $e');
      try {
        final db = await DB.instance;
        await db.insert('trigger_log', {'status': 'fg_crash: $e'});
      } catch (_) {}
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    DebugLogger.log('FG', 'service destroyed');
  }
}
