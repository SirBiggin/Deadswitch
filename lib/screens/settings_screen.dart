import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/settings_service.dart';
import '../services/sms_service.dart';
import '../services/web_server.dart';

const _kCommonCodes = [
  ('🇺🇸 US/CA', '1'),
  ('🇬🇧 UK',    '44'),
  ('🇦🇺 AU',    '61'),
  ('🇮🇳 IN',    '91'),
  ('🇩🇪 DE',    '49'),
  ('🇫🇷 FR',    '33'),
  ('🇧🇷 BR',    '55'),
  ('🇲🇽 MX',    '52'),
  ('🇯🇵 JP',    '81'),
  ('🇨🇳 CN',    '86'),
  ('🇿🇦 ZA',    '27'),
  ('🇳🇿 NZ',    '64'),
];

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _keyCtrl         = TextEditingController();
  final _fromCtrl        = TextEditingController();
  final _testToCtrl      = TextEditingController();
  final _customCodeCtrl  = TextEditingController();
  String _version = '';
  bool _saved = false;
  bool _testing = false;
  String? _testResult;
  bool _testSuccess = false;
  bool _webPortalEnabled = false;
  String? _webIp;
  String _countryCode = '1';

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _fromCtrl.dispose();
    _testToCtrl.dispose();
    _customCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final key    = await SettingsService.httpsmsKey;
    final from   = await SettingsService.httpsmsFrom;
    final portal = await SettingsService.webPortalEnabled;
    final ip     = portal ? await WebServer.localIp : null;
    final code   = await SettingsService.countryCode;
    final info   = await PackageInfo.fromPlatform();
    setState(() {
      _keyCtrl.text     = key;
      _fromCtrl.text    = from;
      _webPortalEnabled = portal;
      _webIp            = ip;
      _countryCode             = code;
      _version                 = info.version;
      _customCodeCtrl.text     = code;
    });
  }

  String _normalizePhone(String phone) =>
      SettingsService.normalizePhone(phone, _countryCode);

  Future<void> _saveCountryCode(String code) async {
    await SettingsService.setCountryCode(code);
    setState(() => _countryCode = code);
  }

  Future<void> _save() async {
    final normalized = _normalizePhone(_fromCtrl.text.trim());
    _fromCtrl.text = normalized;
    await SettingsService.setHttpsmsKey(_keyCtrl.text.trim());
    await SettingsService.setHttpsmsFrom(normalized);
    setState(() => _saved = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _saved = false);
  }

  Future<void> _testSend() async {
    final to = _normalizePhone(_testToCtrl.text.trim());
    _testToCtrl.text = to;
    if (to.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a phone number to test with')));
      return;
    }
    setState(() { _testing = true; _testResult = null; });
    try {
      final resp = await SmsService.sendSms(to, 'DeadSwitch test message');
      setState(() {
        _testSuccess = resp['status'] == 'success' ||
            (resp['data'] != null && resp['status'] != 'error');
        _testResult = resp.entries.map((e) => '${e.key}: ${e.value}').join('\n');
      });
    } catch (e) {
      setState(() { _testSuccess = false; _testResult = 'Exception: $e'; });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _toggleWebPortal(bool enabled) async {
    await SettingsService.setWebPortalEnabled(enabled);
    if (enabled) {
      try { await WebServer.start(); } catch (_) {}
      final ip = await WebServer.localIp;
      setState(() { _webPortalEnabled = true; _webIp = ip; });
    } else {
      await WebServer.stop();
      setState(() { _webPortalEnabled = false; _webIp = null; });
    }
  }

  Future<void> _changePin() async {
    final ctrl1 = TextEditingController();
    final ctrl2 = TextEditingController();
    final ok = await showDialog<bool>(context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1a1a1a),
          title: const Text('Change PIN', style: TextStyle(color: Colors.white)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: ctrl1, obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'New PIN')),
            const SizedBox(height: 12),
            TextField(controller: ctrl2, obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Confirm PIN')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
          ],
        ));
    if (ok != true) return;
    if (ctrl1.text.isEmpty || ctrl1.text != ctrl2.text) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PINs do not match.')));
      return;
    }
    await SettingsService.setPin(ctrl1.text);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN updated.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _section('httpsms API'),
          Card(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              TextField(controller: _keyCtrl, obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'API Key', hintText: 'From httpsms.com/settings')),
              const SizedBox(height: 12),
              TextField(controller: _fromCtrl, keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'From Number', hintText: '+12025551234')),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _save,
                    child: Text(_saved ? 'Saved!' : 'Save Settings'),
                  )),
            ]),
          )),
          const SizedBox(height: 20),
          _section('Test API Connection'),
          Card(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Send a test message to verify your API key and from number are working.',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 12),
              TextField(controller: _testToCtrl, keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Send test to (phone number)', hintText: '+12025551234')),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _testing ? null : _testSend,
                    icon: _testing
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send, size: 16),
                    label: const Text('Send Test Message'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1a3a1a),
                      foregroundColor: const Color(0xFF7ec87e),
                    ),
                  )),
              if (_testResult != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _testSuccess ? const Color(0xFF0d2b0d) : const Color(0xFF2b0d0d),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: _testSuccess ? const Color(0xFF2d6a2d) : const Color(0xFF6a2d2d)),
                  ),
                  child: SelectableText(_testResult!,
                      style: TextStyle(
                        color: _testSuccess ? const Color(0xFF7ec87e) : const Color(0xFFc87e7e),
                        fontSize: 12, fontFamily: 'monospace')),
                ),
              ],
            ]),
          )),
          const SizedBox(height: 20),
          _section('Web Portal'),
          Card(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Enable Web Portal',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  const Text('Configure messages from a browser on the same Wi-Fi network.',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ])),
                Switch(
                  value: _webPortalEnabled,
                  onChanged: _toggleWebPortal,
                  activeColor: const Color(0xFF2563eb),
                ),
              ]),
              if (_webPortalEnabled) ...[
                const SizedBox(height: 12),
                const Text('Open this URL in your browser:',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(
                    child: SelectableText(
                      _webIp != null ? 'http://$_webIp:${WebServer.port}' : 'Getting IP…',
                      style: const TextStyle(
                          color: Color(0xFF7eb8f7), fontSize: 14, fontFamily: 'monospace'),
                    ),
                  ),
                  if (_webIp != null)
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18, color: Color(0xFF7eb8f7)),
                      tooltip: 'Copy to clipboard',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        final url = 'http://$_webIp:${WebServer.port}';
                        Clipboard.setData(ClipboardData(text: url));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('URL copied to clipboard'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                ]),
                const SizedBox(height: 8),
                const Text(
                  'Your app PIN is required to access the portal. '
                  'Keep the app open and the screen active for best results.',
                  style: TextStyle(color: Color(0xFF555555), fontSize: 11),
                ),
              ],
            ]),
          )),
          const SizedBox(height: 20),
          _section('Country Code'),
          Card(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              const Text('+', style: TextStyle(color: Colors.grey, fontSize: 18)),
              const SizedBox(width: 6),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _customCodeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: '1',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                  onSubmitted: (v) {
                    final code = v.replaceAll(RegExp(r'\D'), '');
                    if (code.isNotEmpty) _saveCountryCode(code);
                  },
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Applied to numbers entered without a + prefix.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ]),
          )),
          const SizedBox(height: 20),
          _section('Security'),
          Card(child: ListTile(
            leading: const Icon(Icons.lock, color: Colors.grey),
            title: const Text('Change PIN', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Update your app unlock PIN',
                style: TextStyle(color: Colors.grey)),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: _changePin,
          )),
          const SizedBox(height: 20),
          _section('About'),
          Card(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _infoRow('App', 'DeadSwitch'),
              _infoRow('Version', _version.isEmpty ? '…' : _version),
              _infoRow('SMS Provider', 'httpsms.com'),
              const SizedBox(height: 8),
              const Text(
                'httpsms.com sends SMS via the httpsms Android app installed on your phone. '
                'You must have the httpsms app installed and online for messages to deliver.',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            ]),
          )),
        ]),
      ),
    );
  }

  Widget _section(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 4),
    child: Text(label, style: const TextStyle(
        color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
  );

  Widget _infoRow(String k, String v) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Text('$k: ', style: const TextStyle(color: Colors.grey, fontSize: 13)),
      Text(v, style: const TextStyle(color: Colors.white, fontSize: 13)),
    ]),
  );
}
