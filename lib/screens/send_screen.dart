import 'package:flutter/material.dart';
import '../db/database.dart';
import '../services/sms_service.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});
  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _groups   = [];
  final Set<int> _selectedContacts = {};
  final _messageCtrl = TextEditingController();
  bool _sending = false;
  String _tab = 'contacts'; // 'contacts' or 'groups'

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final db = await DB.instance;
    final contacts = await db.query('contacts', orderBy: 'name');
    final groups   = await db.query('message_groups', orderBy: 'name');
    setState(() { _contacts = contacts; _groups = groups; });
  }

  Future<void> _sendToContacts() async {
    if (_selectedContacts.isEmpty || _messageCtrl.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      final errors = await SmsService.sendAdHoc(
          _selectedContacts.toList(), _messageCtrl.text.trim());
      if (mounted) {
        final msg = errors.isEmpty
            ? 'Messages sent!'
            : 'Some failed: ${errors.join('; ')}';
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg),
                duration: Duration(seconds: errors.isEmpty ? 2 : 6)));
        if (errors.isEmpty) {
          setState(() { _selectedContacts.clear(); _messageCtrl.clear(); });
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendGroup(int groupId, String groupName) async {
    final ok = await showDialog<bool>(context: context,
        builder: (_) => AlertDialog(
          title: const Text('Send group message'),
          content: Text('Send "$groupName" to its recipients now?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true),
                child: const Text('Send')),
          ],
        ));
    if (ok != true) return;
    setState(() => _sending = true);
    try {
      await SmsService.sendGroup(groupId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group messages sent!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            _tabBtn('Ad-hoc Send', 'contacts'),
            const SizedBox(width: 8),
            _tabBtn('Groups', 'groups'),
          ]),
        ),
        Expanded(child: _tab == 'contacts' ? _contactsTab() : _groupsTab()),
      ]),
    );
  }

  Widget _tabBtn(String label, String tab) {
    final sel = _tab == tab;
    return GestureDetector(
      onTap: () => setState(() => _tab = tab),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFF1e3a5f) : const Color(0xFF1a1a1a),
          border: Border.all(color: sel ? const Color(0xFF2a5a8f) : const Color(0xFF333333)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: TextStyle(
            color: sel ? const Color(0xFF7eb8f7) : Colors.grey, fontSize: 13)),
      ),
    );
  }

  Widget _contactsTab() {
    return Column(children: [
      Expanded(child: ListView.builder(
        itemCount: _contacts.length,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemBuilder: (_, i) {
          final c   = _contacts[i];
          final cid = c['id'] as int;
          final sel = _selectedContacts.contains(cid);
          return CheckboxListTile(
            value: sel,
            onChanged: (_) => setState(() {
              if (sel) _selectedContacts.remove(cid); else _selectedContacts.add(cid);
            }),
            title: Text(c['name'] as String, style: const TextStyle(color: Colors.white)),
            subtitle: Text(c['phone'] as String, style: const TextStyle(color: Colors.grey)),
            activeColor: const Color(0xFF2563eb),
            dense: true,
          );
        },
      )),
      Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          TextField(
            controller: _messageCtrl,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Message to send'),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _sending || _selectedContacts.isEmpty ? null : _sendToContacts,
              icon: _sending
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
              label: Text('Send to ${_selectedContacts.length} contact(s)'),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _groupsTab() {
    if (_groups.isEmpty) return const Center(
        child: Text('No groups configured.', style: TextStyle(color: Colors.grey)));
    return ListView.builder(
      itemCount: _groups.length,
      padding: const EdgeInsets.all(12),
      itemBuilder: (_, i) {
        final g = _groups[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            title: Text(g['name'] as String,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            subtitle: Text(g['message'] as String,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: _sending
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : ElevatedButton(
                    onPressed: () => _sendGroup(g['id'] as int, g['name'] as String),
                    child: const Text('Send'),
                  ),
          ),
        );
      },
    );
  }
}
