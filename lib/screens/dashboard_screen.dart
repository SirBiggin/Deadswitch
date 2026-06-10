import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/trigger_service.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../services/permission_service.dart';
import '../db/database.dart';
import 'login_screen.dart';
import 'messages_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  int _tab = 0;
  DateTime? _sendAt;
  Timer? _timer;
  bool _isLocked = false;
  bool _hasPin = false;
  int _statusRefresh = 0;
  int _delaySeconds = 900;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadHasPin();
    _checkPending();
    _checkPermissions();
    _loadDelay();
  }

  Future<void> _checkPermissions() async {
    // Defer until the first frame so the dialog has a valid context to attach to.
    await Future.delayed(Duration.zero);
    if (!mounted) return;
    final ok = await PermissionService.allGranted;
    if (!ok && mounted) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _PermissionSetupDialog(),
      );
    }
  }

  Future<void> _loadHasPin() async {
    _hasPin = await SettingsService.hasPin;
  }

  Future<void> _loadDelay() async {
    final d = await SettingsService.delaySeconds;
    if (mounted) setState(() => _delaySeconds = d);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      if (_hasPin) setState(() => _isLocked = true);
    } else if (state == AppLifecycleState.resumed) {
      _loadHasPin();
      _loadDelay();
      _checkPending();
    }
  }

  Future<void> _checkPending() async {
    final at = await TriggerService.pendingSendAt();
    if (!mounted) return;
    // Treat a past pending trigger as gone — the foreground service will fire it.
    // Don't restore a stale past time or we'll show a negative countdown.
    final effective = (at != null && at.isAfter(DateTime.now())) ? at : null;
    setState(() {
      _sendAt = effective;
      _statusRefresh++;
    });
    if (effective != null) {
      _startTimer();
      NotificationService.showCountdown(effective);
    } else {
      _timer?.cancel();
      NotificationService.cancelCountdown();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_sendAt != null && DateTime.now().isAfter(_sendAt!)) {
        setState(() => _sendAt = null);
        _timer?.cancel();
        NotificationService.cancelCountdown();
      } else {
        setState(() {});
      }
    });
  }

  Future<void> _initiate() async {
    final delay = await SettingsService.delaySeconds;
    final provisional = DateTime.now().add(Duration(seconds: delay));
    setState(() => _sendAt = provisional);
    _startTimer();
    // Post notification BEFORE starting the foreground service so the
    // background-isolate plugin re-registration on the Android main thread
    // cannot race with the flutter_local_notifications MethodChannel call.
    await NotificationService.showCountdown(provisional);
    final at = await TriggerService.initiate();
    if (!mounted) return;
    setState(() => _sendAt = at);
    // Re-post with the exact DB-confirmed sendAt time.
    NotificationService.showCountdown(at);
  }

  Future<void> _abort() async {
    _timer?.cancel();
    setState(() => _sendAt = null);
    NotificationService.cancelCountdown();
    await TriggerService.abort();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  Widget _buildHome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _StatusCard(key: ValueKey(_statusRefresh), onRefresh: _checkPending),
        const SizedBox(height: 12),
        _TriggerCard(sendAt: _sendAt, onInitiate: _initiate, onAbort: _abort, delaySeconds: _delaySeconds),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLocked) {
      return LoginScreen(
        isReauth: true,
        onUnlocked: () => setState(() => _isLocked = false),
      );
    }
    final screens = [
      _buildHome(),
      const MessagesScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('☠  DeadSwitch', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: screens[_tab],
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF1a1a1a),
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          setState(() => _tab = i);
          if (i == 0) { _checkPending(); _loadDelay(); setState(() => _statusRefresh++); }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.message),   label: 'Messages'),
          NavigationDestination(icon: Icon(Icons.settings),  label: 'Settings'),
        ],
      ),
    );
  }
}

class _StatusCard extends StatefulWidget {
  final VoidCallback onRefresh;
  const _StatusCard({super.key, required this.onRefresh});
  @override
  State<_StatusCard> createState() => _StatusCardState();
}

class _StatusCardState extends State<_StatusCard> {
  int _msgCount = 0;
  int _recipientCount = 0;
  String? _lastStatus;
  String? _lastTriggeredAt;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final db   = await DB.instance;
    final msgs = await db.rawQuery('SELECT COUNT(*) as c FROM messages WHERE enabled = 1');
    final recs = await db.rawQuery('SELECT COUNT(DISTINCT mr.phone) as c FROM message_recipients mr JOIN messages m ON m.id = mr.message_id WHERE m.enabled = 1');
    final log  = await db.query('trigger_log', orderBy: 'id DESC', limit: 1);
    if (!mounted) return;
    setState(() {
      _msgCount        = (msgs.first['c'] as int? ?? 0);
      _recipientCount  = (recs.first['c'] as int? ?? 0);
      _lastStatus      = log.isNotEmpty ? log.first['status'] as String? : null;
      _lastTriggeredAt = log.isNotEmpty ? log.first['triggered_at'] as String? : null;
    });
  }

  Color _statusColor(String? s) {
    if (s == null) return Colors.grey;
    if (s == 'success' || s == 'test_ok') return const Color(0xFF7ec87e);
    if (s == 'partial' || s == 'test_partial') return const Color(0xFFf0b04a);
    if (s.startsWith('test_')) return const Color(0xFF7eb8f7);
    if (s.startsWith('wm_') || s.startsWith('fg_')) return const Color(0xFF7eb8f7);
    return const Color(0xFFc87e7e);
  }

  String _formatTs(String? ts) {
    if (ts == null) return '';
    try {
      final dt = DateTime.parse('${ts}Z').toLocal();
      const mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '${mo[dt.month - 1]} ${dt.day}  $h:$m';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    final ts = _formatTs(_lastTriggeredAt);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Expanded(child: Column(children: [
            Text('$_msgCount', style: const TextStyle(
                fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
            const Text('Messages', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ])),
          Expanded(child: Column(children: [
            Text('$_recipientCount', style: const TextStyle(
                fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
            const Text('Recipients', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ])),
          Expanded(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_lastStatus ?? 'NEVER',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                    color: _statusColor(_lastStatus)),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                textAlign: TextAlign.center),
            if (ts.isNotEmpty)
              Text(ts,
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                  textAlign: TextAlign.center),
            const Text('Last trigger', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ])),
        ]),
      ),
    );
  }
}

class _TriggerCard extends StatelessWidget {
  final DateTime? sendAt;
  final VoidCallback onInitiate;
  final VoidCallback onAbort;
  final int delaySeconds;
  const _TriggerCard({this.sendAt, required this.onInitiate, required this.onAbort, required this.delaySeconds});

  String _countdown() {
    if (sendAt == null) return '';
    final remaining = sendAt!.difference(DateTime.now());
    if (remaining.isNegative) return 'Sending…';
    final d = remaining.inDays;
    final h = remaining.inHours % 24;
    final m = remaining.inMinutes % 60;
    final s = remaining.inSeconds % 60;
    if (d > 0) return '${d}d ${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
    return '${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
  }

  static String _formatDelay(int secs) {
    final d = secs ~/ 86400;
    final h = (secs % 86400) ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    final s = secs % 60;
    final parts = <String>[
      if (d > 0) '${d}d',
      if (h > 0) '${h}h',
      if (m > 0) '${m}m',
      if (s > 0) '${s}s',
    ];
    return parts.isEmpty ? '0s' : parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: sendAt == null
            ? Column(children: [
                const Text('Dead Switch',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                Text('Triggers all messages in ${_formatDelay(delaySeconds)}.',
                    style: TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onInitiate,
                    icon: const Text('☠', style: TextStyle(fontSize: 18)),
                    label: const Text('Initiate Dead Switch'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7f1d1d),
                      foregroundColor: const Color(0xFFfca5a5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ])
            : Column(children: [
                const Text('Sending in…', style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 4),
                Text(_countdown(), style: const TextStyle(fontSize: 48,
                    fontWeight: FontWeight.bold, color: Color(0xFFf0b04a))),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onAbort,
                    icon: const Icon(Icons.cancel),
                    label: const Text('Abort — Cancel All'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1a3a1a),
                      foregroundColor: const Color(0xFF7ec87e),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFF2d6a2d)),
                    ),
                  ),
                ),
              ]),
      ),
    );
  }
}

// ── Permission setup dialog ───────────────────────────────────────────────────

class _PermissionSetupDialog extends StatefulWidget {
  const _PermissionSetupDialog();
  @override
  State<_PermissionSetupDialog> createState() => _PermissionSetupDialogState();
}

class _PermissionSetupDialogState extends State<_PermissionSetupDialog> {
  bool _requesting = false;
  bool _smsGranted          = false;
  bool _notifGranted        = false;
  bool _contactsGranted     = false;
  bool _batteryGranted      = false;

  @override
  void initState() {
    super.initState();
    _loadStatuses();
  }

  Future<void> _loadStatuses() async {
    final results = await Future.wait([
      PermissionService.smsStatus,
      PermissionService.notificationStatus,
      PermissionService.contactsStatus,
      PermissionService.batteryStatus,
    ]);
    if (!mounted) return;
    setState(() {
      _smsGranted      = results[0].isGranted;
      _notifGranted    = results[1].isGranted;
      _contactsGranted = results[2].isGranted;
      _batteryGranted  = results[3].isGranted;
    });
  }

  bool get _allGranted =>
      _smsGranted && _notifGranted && _contactsGranted && _batteryGranted;

  Future<void> _grantAll() async {
    setState(() => _requesting = true);

    // 1. Notifications
    if (!_notifGranted) {
      final s = await PermissionService.requestNotification();
      if (mounted) setState(() => _notifGranted = s.isGranted);
    }

    // 2. Contacts
    if (!_contactsGranted) {
      final s = await PermissionService.requestContacts();
      if (mounted) setState(() => _contactsGranted = s.isGranted);
    }

    // 3. Battery optimizations
    if (!_batteryGranted) {
      final s = await PermissionService.requestBattery();
      if (mounted) setState(() => _batteryGranted = s.isGranted);
    }

    // 4. SMS — hard-restricted: guide user through App Info
    if (!_smsGranted) {
      final s = await PermissionService.requestSms();
      if (mounted) setState(() => _smsGranted = s.isGranted);
      if (!_smsGranted && mounted) {
        await _showSmsGuide();
        // Re-check after user returns from settings
        final recheck = await PermissionService.smsStatus;
        if (mounted) setState(() => _smsGranted = recheck.isGranted);
      }
    }

    if (mounted) setState(() => _requesting = false);
  }

  Future<void> _showSmsGuide() async {
    final open = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a1a),
        title: const Text('SMS Permission', style: TextStyle(color: Colors.white)),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Android blocks SMS by default. One-time setup:',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              SizedBox(height: 12),
              _GuideStep(n: '1', text: 'Tap "Open App Info" below'),
              _GuideStep(n: '2', text: 'Tap the  ⋮  menu → "Allow restricted settings"'),
              _GuideStep(n: '3', text: 'Permissions → SMS → Allow'),
              _GuideStep(n: '4', text: 'Return here'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1a3a1a),
              foregroundColor: const Color(0xFF7ec87e),
            ),
            child: const Text('Open App Info'),
          ),
        ],
      ),
    );
    if (open == true) await openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1a1a1a),
      title: const Text('Permissions Required',
          style: TextStyle(color: Colors.white, fontSize: 18)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'DeadSwitch needs the following permissions to work reliably.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            _PermRow(
              icon: Icons.sms,
              label: 'SMS',
              detail: 'Send messages when triggered',
              granted: _smsGranted,
            ),
            _PermRow(
              icon: Icons.notifications,
              label: 'Notifications',
              detail: 'Show countdown timer on lock screen',
              granted: _notifGranted,
            ),
            _PermRow(
              icon: Icons.contacts,
              label: 'Contacts',
              detail: 'Pick recipients from your contacts',
              granted: _contactsGranted,
            ),
            _PermRow(
              icon: Icons.battery_full,
              label: 'Battery',
              detail: 'Stay running when screen is off',
              granted: _batteryGranted,
            ),
          ],
        ),
      ),
      actions: [
        if (_allGranted)
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1a3a1a),
              foregroundColor: const Color(0xFF7ec87e),
            ),
            child: const Text('Done'),
          )
        else ...[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Skip', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: _requesting ? null : _grantAll,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7f1d1d),
              foregroundColor: const Color(0xFFfca5a5),
            ),
            child: _requesting
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2,
                        color: Color(0xFFfca5a5)))
                : const Text('Grant Permissions'),
          ),
        ],
      ],
    );
  }
}

class _PermRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String detail;
  final bool granted;
  const _PermRow({
    required this.icon,
    required this.label,
    required this.detail,
    required this.granted,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      Icon(icon, size: 20, color: Colors.grey),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 14,
            fontWeight: FontWeight.w600)),
        Text(detail, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ])),
      Icon(
        granted ? Icons.check_circle : Icons.radio_button_unchecked,
        size: 20,
        color: granted ? const Color(0xFF7ec87e) : const Color(0xFF555555),
      ),
    ]),
  );
}

class _GuideStep extends StatelessWidget {
  final String n;
  final String text;
  const _GuideStep({required this.n, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 20, height: 20,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
            color: Color(0xFF2563eb), shape: BoxShape.circle),
        child: Text(n, style: const TextStyle(color: Colors.white, fontSize: 11,
            fontWeight: FontWeight.bold)),
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(text,
          style: const TextStyle(color: Colors.white, fontSize: 13))),
    ]),
  );
}
