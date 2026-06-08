import 'dart:async';
import 'package:flutter/material.dart';
import '../services/trigger_service.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
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
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPending();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      _checkPending();
      final paused = _pausedAt;
      _pausedAt = null;
      if (paused != null && DateTime.now().difference(paused).inSeconds >= 5) {
        _maybeRequireReauth();
      }
    }
  }

  Future<void> _maybeRequireReauth() async {
    final hasPin = await SettingsService.hasPin;
    if (!hasPin || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const LoginScreen(isReauth: true),
    ));
  }

  Future<void> _checkPending() async {
    final at = await TriggerService.pendingSendAt();
    if (!mounted) return;
    setState(() => _sendAt = at);
    if (at != null) {
      _startTimer();
    } else {
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
    final provisional = DateTime.now().add(const Duration(minutes: TriggerService.delayMinutes));
    setState(() => _sendAt = provisional);
    _startTimer();
    final at = await TriggerService.initiate();
    if (mounted) setState(() => _sendAt = at);
  }

  Future<void> _abort() async {
    _timer?.cancel();
    setState(() => _sendAt = null);
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
        _StatusCard(onRefresh: _checkPending),
        const SizedBox(height: 12),
        _TriggerCard(sendAt: _sendAt, onInitiate: _initiate, onAbort: _abort),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          if (i == 0) _checkPending();
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
  const _StatusCard({required this.onRefresh});
  @override
  State<_StatusCard> createState() => _StatusCardState();
}

class _StatusCardState extends State<_StatusCard> {
  int _msgCount = 0;
  int _recipientCount = 0;
  String? _lastTrigger;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final db    = await DB.instance;
    final msgs  = await db.rawQuery('SELECT COUNT(*) as c FROM messages');
    final recs  = await db.rawQuery('SELECT COUNT(DISTINCT phone) as c FROM message_recipients');
    final log   = await db.query('trigger_log', orderBy: 'id DESC', limit: 1);
    setState(() {
      _msgCount       = (msgs.first['c'] as int? ?? 0);
      _recipientCount = (recs.first['c'] as int? ?? 0);
      _lastTrigger    = log.isNotEmpty
          ? '${log.first['status']} — ${log.first['triggered_at']}'
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
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
          Expanded(child: Column(children: [
            Text(_lastTrigger != null ? 'TRIGGERED' : 'NEVER',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                    color: _lastTrigger != null ? const Color(0xFF7ec87e) : Colors.grey)),
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
  const _TriggerCard({this.sendAt, required this.onInitiate, required this.onAbort});

  String _countdown() {
    if (sendAt == null) return '';
    final remaining = sendAt!.difference(DateTime.now());
    if (remaining.isNegative) return 'Sending…';
    final m = remaining.inMinutes.toString().padLeft(2, '0');
    final s = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
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
                const Text('Triggers all messages in 15 minutes.',
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
