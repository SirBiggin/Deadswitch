import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DB {
  static Database? _db;

  static Future<Database> get instance async {
    _db ??= await _open();
    return _db!;
  }

  static Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'deadswitch.db');
    return openDatabase(path, version: 4,
      onCreate: (db, _) async {
        await db.execute('''CREATE TABLE messages(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          message TEXT NOT NULL DEFAULT '',
          created_at TEXT DEFAULT CURRENT_TIMESTAMP)''');
        await db.execute('''CREATE TABLE message_recipients(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          message_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          phone TEXT NOT NULL)''');
        await db.execute('''CREATE TABLE pending_triggers(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          send_at TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'pending')''');
        await db.execute('''CREATE TABLE trigger_log(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          triggered_at TEXT DEFAULT CURRENT_TIMESTAMP,
          status TEXT)''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''CREATE TABLE IF NOT EXISTS group_recipients(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            group_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            phone TEXT NOT NULL)''');
        }
        if (oldVersion < 3) {
          await db.execute('''CREATE TABLE IF NOT EXISTS messages(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            message TEXT NOT NULL DEFAULT '',
            created_at TEXT DEFAULT CURRENT_TIMESTAMP)''');
          await db.execute('''CREATE TABLE IF NOT EXISTS message_recipients(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            message_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            phone TEXT NOT NULL)''');
          // Migrate contacts (each becomes a message with one recipient)
          final contacts = await db.query('contacts');
          for (final c in contacts) {
            final mid = await db.insert('messages', {
              'name': c['name'],
              'message': c['message'] ?? '',
              'created_at': c['created_at'],
            });
            await db.insert('message_recipients', {
              'message_id': mid,
              'name': c['name'],
              'phone': c['phone'],
            });
          }
          // Migrate message_groups + group_recipients
          final groups = await db.query('message_groups');
          for (final g in groups) {
            final mid = await db.insert('messages', {
              'name': g['name'],
              'message': g['message'] ?? '',
              'created_at': g['created_at'],
            });
            final recs = await db.query('group_recipients',
                where: 'group_id = ?', whereArgs: [g['id']]);
            for (final r in recs) {
              await db.insert('message_recipients', {
                'message_id': mid,
                'name': r['name'],
                'phone': r['phone'],
              });
            }
          }
        }
        if (oldVersion < 4) {
          // Remove duplicate recipients within the same message (keep lowest id per message_id+phone)
          await db.execute('''
            DELETE FROM message_recipients
            WHERE id NOT IN (
              SELECT MIN(id) FROM message_recipients
              GROUP BY message_id, phone
            )
          ''');
        }
      },
    );
  }
}
