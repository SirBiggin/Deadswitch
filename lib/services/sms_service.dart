import 'dart:convert';
import 'package:http/http.dart' as http;
import '../db/database.dart';
import 'settings_service.dart';

class SmsService {
  static Future<String> _norm(String phone) async {
    final code = await SettingsService.countryCode;
    return SettingsService.normalizePhone(phone, code);
  }

  static Future<Map<String, dynamic>> sendSms(String to, String message) async {
    final key  = await SettingsService.httpsmsKey;
    final from = await _norm(await SettingsService.httpsmsFrom);
    final normalizedTo = await _norm(to);
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
