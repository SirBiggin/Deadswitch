import 'dart:async';

import 'package:flutter/material.dart';
import '../services/trigger_service.dart';
import '../db/database.dart';
import 'messages_screen.dart';
import 'groups_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _tab = 0;
  DateTime? _sendAt;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _checkPending();
  }

  Future<void> _checkPending() async {
    final at = await TriggerService.pendingSendAt();
    setState(() => _sendAt = at);
    if (at != null) _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_sendAt != null && DateTime.now().isAfter(_sendAt!)) {
        setState(() => _sendAt = null);
        _timer?.cancel();
      } else {
        setState(() {});
      }
    });
  }

  Future<void> _initiate() async {
    final at = await TriggerService.initiate();
    setState(() => _sendAt = at);
    _startTimer();
  }

  Future<void> _abort() async {
    await TriggerService.abort();
    _timer?.cancel();
    setState(() => _sendAt = null);
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  Widget _buildHome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _StatusCard(onRefresh: _checkPending),
        const SizedBox(height: 12),
        _TriggerCard(
          sendAt: _sendAt,
          onInitiate: _initiate,
          onAbort: _abort,
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _buildHome(),
      const MessagesScreen(),
      const GroupsScreen(),
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
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.message), label: 'Messages'),
          NavigationDestination(icon: Icon(Icons.group), label: 'Groups'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
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
  int _contactCount = 0;
  String? _lastTrigger;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final db = await DB.instance;
    final rows = await db.rawQuery("""
      SELECT COUNT(*) FROM (
        SELECT phone FROM contacts
        UNION
        SELECT phone FROM group_recipients
      )""");
    final count = rows.isNotEmpty ? (rows.first.values.first as int? ?? 0) : 0;
    final log = await db.query('trigger_log', orderBy: 'id DESC', limit: 1);
    setState(() {
      _contactCount = count;
      _lastTrigger = log.isNotEmpty ? '${log.first['status']} — ${log.first['triggered_at']}' : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Expanded(child: Column(children: [
            Text('$_contactCount', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
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
                const Text('Dead Switch', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                const Text('Triggers all contacts and groups in 15 minutes.',
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
                Text(_countdown(), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold,
                    color: Color(0xFFf0b04a), fontFeatures: [])),
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
