import 'package:flutter/services.dart';
import '../db/database.dart';
import 'settings_service.dart';

class SmsService {
  static const _nativeChannel = MethodChannel('com.deadswitch.deadswitch_app/sms');

  static Future<String> _norm(String phone) async {
    final code = await SettingsService.countryCode;
    return SettingsService.normalizePhone(phone, code);
  }

  static Future<Map<String, dynamic>> sendSms(String to, String message) async {
    try {
      final normalized = await _norm(to);
      await _nativeChannel.invokeMethod<String>('sendSms', {
        'to': normalized,
        'message': message,
      });
      return {'status': 'success', 'message': 'Sent via native SMS'};
    } on PlatformException catch (e) {
      return {'status': 'error', 'message': e.message ?? 'SMS send failed'};
    } catch (e) {
      return {'status': 'error', 'message': '$e'};
    }
  }

  static Future<Map<String, dynamic>> _sendGroup(
      List<String> phones, String message) async {
    try {
      final normalized = await Future.wait(phones.map(_norm));
      await _nativeChannel.invokeMethod<String>('sendGroupSms', {
        'recipients': normalized,
        'message': message,
      });
      return {'status': 'success', 'message': 'Sent as group MMS'};
    } on PlatformException catch (e) {
      return {'status': 'error', 'message': e.message ?? 'Group MMS failed'};
    } catch (e) {
      return {'status': 'error', 'message': '$e'};
    }
  }

  static Future<List<Map<String, dynamic>>> sendAllMessages() async {
    final db       = await DB.instance;
    final messages = await db.query('messages', where: 'enabled = 1');
    final results  = <Map<String, dynamic>>[];

    for (final m in messages) {
      final label      = m['name'] as String;
      final body       = m['message'] as String;
      final recipients = await db.query('message_recipients',
          where: 'message_id = ?', whereArgs: [m['id']]);

      if (recipients.isEmpty) continue;

      final phones = recipients.map((r) => r['phone'] as String).toList();

      if (phones.length > 1) {
        final resp = await _sendGroup(phones, body);
        if (resp['status'] == 'success') {
          results.add({
            'label':   label,
            'contact': 'Group (${phones.length})',
            'status':  'sent',
            'detail':  resp['message'] ?? '',
          });
          continue;
        }
        // Group MMS failed — fall back to individual SMS
      }

      for (final r in recipients) {
        try {
          final resp = await sendSms(r['phone'] as String, body);
          results.add({
            'label':   label,
            'contact': r['name'] as String,
            'status':  resp['status'] == 'success' ? 'sent' : 'failed',
            'detail':  resp['message'] ?? '',
          });
        } catch (e) {
          results.add({
            'label':   label,
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
