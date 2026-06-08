import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import '../db/database.dart';
import 'settings_service.dart';
import 'sms_service.dart';

@pragma('vm:entry-point')
void webPortalTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_WebPortalTaskHandler());
}

class _WebPortalTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}
  @override
  void onRepeatEvent(DateTime timestamp) {}
  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}

class WebServer {
  static HttpServer? _server;
  static const int port = 8080;
  static String? _html;

  static bool get isRunning => _server != null;

  static Future<String?> get localIp async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<void> start() async {
    if (_server != null) return;
    _html = await rootBundle.loadString('assets/web/index.html');

    final router = Router();
    router.get('/', _serveIndex);
    router.get('/favicon.ico', (Request r) => Response.notFound(''));
    router.get('/api/messages', _getMessages);
    router.post('/api/messages', _createMessage);
    router.put('/api/messages/<id>', (Request r, String id) => _updateMessage(r, id));
    router.delete('/api/messages/<id>', (Request r, String id) => _deleteMessage(r, id));
    router.get('/api/phonebook', _getPhonebook);
    router.get('/api/settings', _getSettings);
    router.put('/api/settings', _updateSettings);
    router.post('/api/settings/test', _testSend);
    router.get('/<_|.*>', _serveIndex);

    final handler = Pipeline()
        .addMiddleware(_corsMiddleware())
        .addMiddleware(_authMiddleware())
        .addHandler(router.call);

    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);

    final ip = await localIp;
    final notifText = ip != null ? 'http://$ip:$port' : 'Port $port';
    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'Web Portal Active',
      notificationText: notifText,
      callback: webPortalTaskCallback,
    );
  }

  static Future<void> stop() async {
    await FlutterForegroundTask.stopService();
    await _server?.close(force: true);
    _server = null;
    _html = null;
  }

  // ── Middleware ────────────────────────────────────────────────────────────

  static Middleware _corsMiddleware() => (h) => (req) async {
        if (req.method == 'OPTIONS') {
          return Response.ok('', headers: _corsHeaders);
        }
        final res = await h(req);
        return res.change(headers: {...res.headers, ..._corsHeaders});
      };

  static const _corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  };

  static Middleware _authMiddleware() => (h) => (req) async {
        if (!req.url.path.startsWith('api/')) return h(req);
        final pin = await SettingsService.pin;
        if (pin.isEmpty) return h(req);
        final auth = req.headers['authorization'] ?? '';
        if (auth != 'Bearer $pin') {
          return Response.unauthorized(
            jsonEncode({'error': 'Unauthorized'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
        return h(req);
      };

  // ── Handlers ──────────────────────────────────────────────────────────────

  static Response _serveIndex(Request req) =>
      Response.ok(_html ?? '', headers: {'Content-Type': 'text/html; charset=utf-8'});

  // Messages
  static Future<Response> _getMessages(Request req) async {
    final db = await DB.instance;
    final msgs = await db.query('messages', orderBy: 'name ASC');
    final result = <Map<String, dynamic>>[];
    for (final m in msgs) {
      final recs = await db.query('message_recipients',
          where: 'message_id = ?', whereArgs: [m['id']]);
      result.add({
        'id': m['id'],
        'name': m['name'],
        'message': m['message'],
        'recipients': recs.map((r) => {
          'id': r['id'],
          'name': r['name'],
          'phone': r['phone'],
        }).toList(),
      });
    }
    return _ok(result);
  }

  static Future<Response> _createMessage(Request req) async {
    final b = await _body(req);
    final db = await DB.instance;
    final id = await db.insert('messages', {
      'name': b['name'] ?? '',
      'message': b['message'] ?? '',
    });
    for (final r in (b['recipients'] as List? ?? [])) {
      await db.insert('message_recipients', {
        'message_id': id,
        'name': r['name'] ?? '',
        'phone': r['phone'] ?? '',
      });
    }
    return _ok({'id': id}, status: 201);
  }

  static Future<Response> _updateMessage(Request req, String id) async {
    final mid = int.parse(id);
    final b = await _body(req);
    final db = await DB.instance;
    await db.update('messages',
        {'name': b['name'] ?? '', 'message': b['message'] ?? ''},
        where: 'id = ?', whereArgs: [mid]);
    await db.delete('message_recipients', where: 'message_id = ?', whereArgs: [mid]);
    for (final r in (b['recipients'] as List? ?? [])) {
      await db.insert('message_recipients', {
        'message_id': mid,
        'name': r['name'] ?? '',
        'phone': r['phone'] ?? '',
      });
    }
    return _ok({'ok': true});
  }

  static Future<Response> _deleteMessage(Request req, String id) async {
    final mid = int.parse(id);
    final db = await DB.instance;
    await db.delete('message_recipients', where: 'message_id = ?', whereArgs: [mid]);
    await db.delete('messages', where: 'id = ?', whereArgs: [mid]);
    return _ok({'ok': true});
  }

  // Phonebook
  static Future<Response> _getPhonebook(Request req) async {
    try {
      final contacts = await FlutterContacts.getAll(
          properties: {ContactProperty.phone});
      final result = <Map<String, dynamic>>[];
      for (final c in contacts) {
        if (c.phones.isEmpty) continue;
        result.add({
          'name': c.displayName,
          'phones': c.phones.map((p) => p.number).toList(),
        });
      }
      result.sort((a, b) =>
          (a['name'] as String).compareTo(b['name'] as String));
      return _ok(result);
    } catch (e) {
      return _ok(<String, dynamic>{'error': '$e'}, status: 500);
    }
  }

  // Settings
  static Future<Response> _getSettings(Request req) async => _ok({
        'httpsms_key': await SettingsService.httpsmsKey,
        'httpsms_from': await SettingsService.httpsmsFrom,
      });

  static Future<Response> _updateSettings(Request req) async {
    final b = await _body(req);
    if (b['httpsms_key'] != null) await SettingsService.setHttpsmsKey(b['httpsms_key']);
    if (b['httpsms_from'] != null) await SettingsService.setHttpsmsFrom(b['httpsms_from']);
    return _ok({'ok': true});
  }

  static Future<Response> _testSend(Request req) async {
    final b = await _body(req);
    final to = b['to'] as String? ?? '';
    try {
      final result = await SmsService.sendSms(to, 'DeadSwitch test message');
      return _ok(result);
    } catch (e) {
      return _ok({'error': '$e'}, status: 500);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _body(Request req) async =>
      jsonDecode(await req.readAsString()) as Map<String, dynamic>;

  static Response _ok(dynamic data, {int status = 200}) => Response(
        status,
        body: jsonEncode(data),
        headers: {'Content-Type': 'application/json'},
      );
}
