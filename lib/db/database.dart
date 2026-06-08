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
    return openDatabase(path, version: 2,
      onCreate: (db, _) async {
        await db.execute('''CREATE TABLE contacts(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          phone TEXT NOT NULL,
          message TEXT NOT NULL DEFAULT '',
          created_at TEXT DEFAULT CURRENT_TIMESTAMP)''');
        await db.execute('''CREATE TABLE tags(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT UNIQUE NOT NULL)''');
        await db.execute('''CREATE TABLE contact_tags(
          contact_id INTEGER NOT NULL,
          tag_id INTEGER NOT NULL,
          PRIMARY KEY(contact_id, tag_id))''');
        await db.execute('''CREATE TABLE message_groups(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          message TEXT NOT NULL,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP)''');
        await db.execute('''CREATE TABLE group_recipients(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          group_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          phone TEXT NOT NULL)''');
        await db.execute('''CREATE TABLE pending_triggers(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          send_at TEXT NOT NULL,
          group_id INTEGER,
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
      },
    );
  }
}
