import 'dart:convert';
import 'package:http/http.dart' as http;
import '../db/database.dart';
import 'settings_service.dart';

class SmsService {
  static Future<String> _normalizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return Future.value('+1$digits');
    if (digits.length == 11 && digits.startsWith('1')) return Future.value('+$digits');
    return Future.value(phone.startsWith('+') ? phone : '+$digits');
  }

  static Future<Map<String, dynamic>> sendSms(String to, String message) async {
    final key  = await SettingsService.httpsmsKey;
    final from = await _normalizePhone(await SettingsService.httpsmsFrom);
    final normalizedTo = await _normalizePhone(to);
    final res = await http.post(
      Uri.parse('https://api.httpsms.com/v1/messages/send'),
      headers: {'x-api-key': key, 'Content-Type': 'application/json'},
      body: jsonEncode({'content': message, 'from': from, 'to': normalizedTo}),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> sendAllMessages() async {
    final db = await DB.instance;
    final contacts = await db.query('contacts');
    final results = <Map<String, dynamic>>[];
    for (final c in contacts) {
      try {
        final phone = await _normalizePhone(c['phone'] as String);
        final resp = await sendSms(phone, c['message'] as String);
        results.add({
          'contact': c['name'],
          'status': resp['status'] == 'success' ? 'sent' : 'failed',
          'detail': resp['message'] ?? '',
        });
      } catch (e) {
        results.add({'contact': c['name'], 'status': 'failed', 'detail': '$e'});
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
        final phone = await _normalizePhone(c['phone'] as String);
        final resp = await sendSms(phone, group['message'] as String);
        results.add({
          'contact': c['name'],
          'status': resp['status'] == 'success' ? 'sent' : 'failed',
          'detail': resp['message'] ?? '',
        });
      } catch (e) {
        results.add({'contact': c['name'], 'status': 'failed', 'detail': '$e'});
      }
    }
    return results;
  }

  // Returns list of error strings; empty = all succeeded
  static Future<List<String>> sendAdHoc(List<int> contactIds, String message) async {
    final db = await DB.instance;
    final errors = <String>[];
    for (final cid in contactIds) {
      final rows = await db.query('contacts', where: 'id = ?', whereArgs: [cid]);
      if (rows.isEmpty) continue;
      final name = rows.first['name'] as String;
      try {
        final phone = await _normalizePhone(rows.first['phone'] as String);
        final resp = await sendSms(phone, message);
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
