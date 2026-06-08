import 'dart:convert';
import 'package:http/http.dart' as http;
import '../db/database.dart';
import 'settings_service.dart';

class SmsService {
  static String _normalizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return '+1$digits';
    if (digits.length == 11 && digits.startsWith('1')) return '+$digits';
    return phone.startsWith('+') ? phone : '+$digits';
  }

  static Future<Map<String, dynamic>> sendSms(String to, String message) async {
    final key  = await SettingsService.httpsmsKey;
    final from = _normalizePhone(await SettingsService.httpsmsFrom);
    final normalizedTo = _normalizePhone(to);
    final res = await http.post(
      Uri.parse('https://api.httpsms.com/v1/messages/send'),
      headers: {'x-api-key': key, 'Content-Type': 'application/json'},
      body: jsonEncode({'content': message, 'from': from, 'to': normalizedTo}),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> sendAllMessages() async {
    final db = await DB.instance;
    final messages = await db.query('messages');
    final results = <Map<String, dynamic>>[];
    for (final m in messages) {
      final recipients = await db.query('message_recipients',
          where: 'message_id = ?', whereArgs: [m['id']]);
      for (final r in recipients) {
        try {
          final resp = await sendSms(r['phone'] as String, m['message'] as String);
          results.add({
            'label':   m['name'],
            'contact': r['name'],
            'status':  resp['status'] == 'success' ? 'sent' : 'failed',
            'detail':  resp['message'] ?? '',
          });
        } catch (e) {
          results.add({
            'label':   m['name'],
            'contact': r['name'] as String,
            'status':  'failed',
            'detail':  '$e',
          });
        }
      }
    }
    return results;
  }
}
