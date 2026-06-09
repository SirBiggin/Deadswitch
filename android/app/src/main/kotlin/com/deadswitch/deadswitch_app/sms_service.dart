import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../db/database.dart';
import 'settings_service.dart';

class SmsService {
  static const _nativeChannel = MethodChannel('com.deadswitch.deadswitch_app/sms');

  static Future<String> _norm(String phone) async {
    final code = await SettingsService.countryCode;
    return SettingsService.normalizePhone(phone, code);
  }

  static Future<Map<String, dynamic>> sendSms(String to, String message) async {
    final useNative = await SettingsService.nativeSmsEnabled;
    if (useNative) return _sendNative(to, message);
    return _sendHttpsms(to, message);
  }

  static Future<Map<String, dynamic>> _sendNative(String to, String message) async {
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

  static Future<Map<String, dynamic>> _sendNativeGroup(
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

  static Future<Map<String, dynamic>> _sendHttpsms(String to, String message) async {
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
    final db         = await DB.instance;
    final messages   = await db.query('messages');
    final results    = <Map<String, dynamic>>[];
    final useNative  = await SettingsService.nativeSmsEnabled;

    for (final m in messages) {
      final label      = m['name'] as String;
      final body       = m['message'] as String;
      final recipients = await db.query('message_recipients',
          where: 'message_id = ?', whereArgs: [m['id']]);

      if (recipients.isEmpty) continue;

      final phones = recipients.map((r) => r['phone'] as String).toList();

      // Group MMS path: native + 2 or more recipients
      if (useNative && phones.length > 1) {
        final resp = await _sendNativeGroup(phones, body);
        if (resp['status'] == 'success') {
          results.add({
            'label':   label,
            'contact': 'Group (${phones.length})',
            'status':  'sent',
            'detail':  resp['message'] ?? '',
          });
          continue;
        }
        // MMS failed — fall through to individual SMS for each recipient
      }

      // Individual sends (httpsms, single recipient, or MMS fallback)
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
