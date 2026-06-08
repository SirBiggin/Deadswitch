import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../db/database.dart';

class SmsService {
  static const _channel = MethodChannel('com.deadswitch/sms');

  static String _normalizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return '+1$digits';
    if (digits.length == 11 && digits.startsWith('1')) return '+$digits';
    return phone.startsWith('+') ? phone : '+$digits';
  }

  static Future<Map<String, dynamic>> sendSms(String to, String message) async {
    final status = await Permission.sms.request();
    if (!status.isGranted) {
      return {'status': 'error', 'message': 'SMS permission denied'};
    }
    final normalizedTo = _normalizePhone(to);
    try {
      final res = await _channel.invokeMethod<Map>('sendSms', {
        'to': normalizedTo,
        'message': message,
      });
      return Map<String, dynamic>.from(res ?? {'status': 'success'});
    } on PlatformException catch (e) {
      return {'status': 'error', 'message': e.message ?? 'SMS failed'};
    }
  }

  static Future<List<Map<String, dynamic>>> sendAllMessages() async {
    final db = await DB.instance;
    final contacts = await db.query('contacts');
    final results = <Map<String, dynamic>>[];
    for (final c in contacts) {
      try {
        final resp = await sendSms(c['phone'] as String, c['message'] as String);
        results.add({
          'contact': c['name'],
          'status': resp['status'] == 'success' ? 'sent' : 'failed',
          'detail': resp['message'] ?? '',
        });
      } catch (e) {
        results.add({'contact': c['name'] as String, 'status': 'failed', 'detail': '$e'});
      }
    }
    return results;
  }

  static Future<List<Map<String, dynamic>>> sendGroup(int groupId) async {
    final db = await DB.instance;
    final group = (await db.query('message_groups',
        where: 'id = ?', whereArgs: [groupId])).firstOrNull;
    if (group == null) return [];
    final rows = await db.query('group_recipients',
        where: 'group_id = ?', whereArgs: [groupId]);
    final results = <Map<String, dynamic>>[];
    for (final c in rows) {
      try {
        final resp = await sendSms(c['phone'] as String, group['message'] as String);
        results.add({
          'contact': c['name'],
          'status': resp['status'] == 'success' ? 'sent' : 'failed',
          'detail': resp['message'] ?? '',
        });
      } catch (e) {
        results.add({'contact': c['name'] as String, 'status': 'failed', 'detail': '$e'});
      }
    }
    return results;
  }

  static Future<List<String>> sendAdHoc(List<int> contactIds, String message) async {
    final db = await DB.instance;
    final errors = <String>[];
    for (final cid in contactIds) {
      final rows = await db.query('contacts', where: 'id = ?', whereArgs: [cid]);
      if (rows.isEmpty) continue;
      final name = rows.first['name'] as String;
      try {
        final resp = await sendSms(rows.first['phone'] as String, message);
        if (resp['status'] == 'error') {
          errors.add('$name: ${resp['message'] ?? resp.toString()}');
        }
      } catch (e) {
        errors.add('$name: $e');
      }
    }
    return errors;
  }
}
