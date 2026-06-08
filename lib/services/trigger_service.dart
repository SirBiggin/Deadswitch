import 'package:workmanager/workmanager.dart';
import '../db/database.dart';
import 'notification_service.dart';

class TriggerService {
  static const taskName    = 'deadswitch_send';
  static const _taskTag    = 'deadswitch';
  static const delayMinutes = 15;

  static Future<DateTime> initiate() async {
    final db     = await DB.instance;
    final sendAt = DateTime.now().toUtc().add(const Duration(minutes: delayMinutes));
    await db.update('pending_triggers', {'status': 'cancelled'},
        where: "status = 'pending'");
    await db.insert('pending_triggers', {'send_at': sendAt.toIso8601String()});
    await Workmanager().cancelByTag(_taskTag);
    await Workmanager().registerOneOffTask(
      taskName, taskName,
      tag: _taskTag,
      initialDelay: const Duration(minutes: delayMinutes),
    );
    await NotificationService.showCountdown(sendAt);
    return sendAt;
  }

  static Future<void> abort() async {
    final db = await DB.instance;
    await db.update('pending_triggers', {'status': 'cancelled'},
        where: "status = 'pending'");
    await Workmanager().cancelByTag(_taskTag);
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
