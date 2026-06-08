import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import '../db/database.dart';
import 'settings_service.dart';
import 'sms_service.dart';

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
    router.get('/api/contacts', _getContacts);
    router.post('/api/contacts', _createContact);
    router.put('/api/contacts/<id>', (Request r, String id) => _updateContact(r, id));
    router.delete('/api/contacts/<id>', (Request r, String id) => _deleteContact(r, id));
    router.get('/api/groups', _getGroups);
    router.post('/api/groups', _createGroup);
    router.put('/api/groups/<id>', (Request r, String id) => _updateGroup(r, id));
    router.delete('/api/groups/<id>', (Request r, String id) => _deleteGroup(r, id));
    router.get('/api/settings', _getSettings);
    router.put('/api/settings', _updateSettings);
    router.post('/api/settings/test', _testSend);
    router.get('/<_|.*>', _serveIndex);

    final handler = Pipeline()
        .addMiddleware(_corsMiddleware())
        .addMiddleware(_authMiddleware())
        .addHandler(router.call);

    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  }

  static Future<void> stop() async {
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

  // Contacts
  static Future<Response> _getContacts(Request req) async {
    final db = await DB.instance;
    final rows = await db.query('contacts', orderBy: 'name');
    return _ok(rows
        .map((r) => {
              'id': r['id'],
              'name': r['name'],
              'phone': r['phone'],
              'message': r['message'],
            })
        .toList());
  }

  static Future<Response> _createContact(Request req) async {
    final b = await _body(req);
    final db = await DB.instance;
    final id = await db.insert('contacts', {
      'name': b['name'] ?? '',
      'phone': b['phone'] ?? '',
      'message': b['message'] ?? '',
    });
    return _ok({'id': id}, status: 201);
  }

  static Future<Response> _updateContact(Request req, String id) async {
    final b = await _body(req);
    final db = await DB.instance;
    await db.update(
      'contacts',
      {'name': b['name'] ?? '', 'phone': b['phone'] ?? '', 'message': b['message'] ?? ''},
      where: 'id = ?',
      whereArgs: [int.parse(id)],
    );
    return _ok({'ok': true});
  }

  static Future<Response> _deleteContact(Request req, String id) async {
    final db = await DB.instance;
    await db.delete('contacts', where: 'id = ?', whereArgs: [int.parse(id)]);
    return _ok({'ok': true});
  }

  // Groups
  static Future<Response> _getGroups(Request req) async {
    final db = await DB.instance;
    final groups = await db.query('message_groups', orderBy: 'name');
    final result = <Map<String, dynamic>>[];
    for (final g in groups) {
      final recs =
          await db.query('group_recipients', where: 'group_id = ?', whereArgs: [g['id']]);
      result.add({
        'id': g['id'],
        'name': g['name'],
        'message': g['message'],
        'recipients': recs
            .map((r) => {'id': r['id'], 'name': r['name'], 'phone': r['phone']})
            .toList(),
      });
    }
    return _ok(result);
  }

  static Future<Response> _createGroup(Request req) async {
    final b = await _body(req);
    final db = await DB.instance;
    final gid = await db.insert('message_groups', {
      'name': b['name'] ?? '',
      'message': b['message'] ?? '',
    });
    for (final r in (b['recipients'] as List? ?? [])) {
      await db.insert('group_recipients', {
        'group_id': gid,
        'name': r['name'] ?? '',
        'phone': r['phone'] ?? '',
      });
    }
    return _ok({'id': gid}, status: 201);
  }

  static Future<Response> _updateGroup(Request req, String id) async {
    final gid = int.parse(id);
    final b = await _body(req);
    final db = await DB.instance;
    await db.update('message_groups',
        {'name': b['name'] ?? '', 'message': b['message'] ?? ''},
        where: 'id = ?', whereArgs: [gid]);
    await db.delete('group_recipients', where: 'group_id = ?', whereArgs: [gid]);
    for (final r in (b['recipients'] as List? ?? [])) {
      await db.insert('group_recipients', {
        'group_id': gid,
        'name': r['name'] ?? '',
        'phone': r['phone'] ?? '',
      });
    }
    return _ok({'ok': true});
  }

  static Future<Response> _deleteGroup(Request req, String id) async {
    final gid = int.parse(id);
    final db = await DB.instance;
    await db.delete('group_recipients', where: 'group_id = ?', whereArgs: [gid]);
    await db.delete('message_groups', where: 'id = ?', whereArgs: [gid]);
    return _ok({'ok': true});
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
