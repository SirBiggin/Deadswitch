import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../db/database.dart';
import '../services/settings_service.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db   = await DB.instance;
    final msgs = await db.query('messages', orderBy: 'name ASC');
    final result = <Map<String, dynamic>>[];
    for (final m in msgs) {
      final recs = await db.query('message_recipients',
          where: 'message_id = ?', whereArgs: [m['id']]);
      result.add({...m, 'recipients': List<Map<String, dynamic>>.from(recs)});
    }
    if (mounted) setState(() { _messages = result; _loading = false; });
  }

  Future<void> _delete(int id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a1a),
        title: const Text('Delete Message?', style: TextStyle(color: Colors.white)),
        content: Text('Delete $name?', style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFc87e7e)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final db = await DB.instance;
    await db.delete('message_recipients', where: 'message_id = ?', whereArgs: [id]);
    await db.delete('messages', where: 'id = ?', whereArgs: [id]);
    _load();
  }

  Future<void> _toggleEnabled(int id, bool currentlyEnabled) async {
    final db = await DB.instance;
    await db.update('messages', {'enabled': currentlyEnabled ? 0 : 1},
        where: 'id = ?', whereArgs: [id]);
    setState(() {
      final idx = _messages.indexWhere((m) => m['id'] == id);
      if (idx != -1) {
        _messages[idx] = {..._messages[idx], 'enabled': currentlyEnabled ? 0 : 1};
      }
    });
  }

  void _openForm([Map<String, dynamic>? existing]) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _MessageFormScreen(existing: existing),
    )).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _messages.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.message_outlined, color: Colors.grey, size: 52),
                  const SizedBox(height: 12),
                  const Text('No messages configured.',
                      style: TextStyle(color: Colors.grey, fontSize: 14)),
                  const SizedBox(height: 4),
                  const Text('Tap + to create one.',
                      style: TextStyle(color: Color(0xFF555555), fontSize: 12)),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) {
                    final m = _messages[i];
                    return _MessageCard(
                      data: m,
                      onEdit:   () => _openForm(m),
                      onDelete: () => _delete(m['id'] as int, m['name'] as String),
                      onToggle: () => _toggleEnabled(m['id'] as int, (m['enabled'] as int? ?? 1) != 0),
                    );
                  },
                ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;
  const _MessageCard({required this.data, required this.onEdit, required this.onDelete, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final recipients = (data['recipients'] as List<Map<String, dynamic>>? ?? []);
    final count      = recipients.length;
    final names      = recipients.map((r) => r['name'] as String).join(', ');
    final message    = data['message'] as String? ?? '';
    final enabled    = (data['enabled'] as int? ?? 1) != 0;

    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(data['name'] as String,
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  if (!enabled) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF333333),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('disabled',
                          style: TextStyle(color: Color(0xFF888888), fontSize: 10)),
                    ),
                  ],
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.people, size: 13, color: Color(0xFF2563eb)),
                  const SizedBox(width: 4),
                  Expanded(child: Text(
                    count == 0
                        ? 'No recipients'
                        : '$count recipient${count == 1 ? '' : 's'}: $names',
                    style: const TextStyle(color: Color(0xFF888888), fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )),
                ]),
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(message,
                      style: const TextStyle(color: Color(0xFF666666), fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ])),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Transform.scale(
                  scale: 0.7,
                  child: Switch(
                    value: enabled,
                    onChanged: (_) => onToggle(),
                    activeColor: const Color(0xFF2563eb),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF888888)),
                  onPressed: onEdit,
                  tooltip: 'Edit',
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(height: 4),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFF884444)),
                  onPressed: onDelete,
                  tooltip: 'Delete',
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─── Add / Edit Form ─────────────────────────────────────────────────────────

class _MessageFormScreen extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _MessageFormScreen({this.existing});
  @override
  State<_MessageFormScreen> createState() => _MessageFormScreenState();
}

class _MessageFormScreenState extends State<_MessageFormScreen> {
  final _nameCtrl     = TextEditingController();
  final _msgCtrl      = TextEditingController();
  final _manNameCtrl  = TextEditingController();
  final _manPhoneCtrl = TextEditingController();
  List<Map<String, String>> _recipients = [];
  bool _showManual = false;
  bool _saving     = false;
  String _countryCode = '1';

  @override
  void initState() {
    super.initState();
    SettingsService.countryCode.then((c) { if (mounted) setState(() => _countryCode = c); });
    if (widget.existing != null) {
      _nameCtrl.text = widget.existing!['name']    as String? ?? '';
      _msgCtrl.text  = widget.existing!['message'] as String? ?? '';
      final recs = widget.existing!['recipients'] as List<Map<String, dynamic>>? ?? [];
      _recipients = recs.map((r) => {
        'name':  r['name']  as String,
        'phone': r['phone'] as String,
      }).toList();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _msgCtrl.dispose();
    _manNameCtrl.dispose(); _manPhoneCtrl.dispose();
    super.dispose();
  }

  String _norm(String phone) =>
      SettingsService.normalizePhone(phone, _countryCode);

  Future<void> _pickContact() async {
    try {
      final status = await FlutterContacts.permissions.request(PermissionType.read);
      if (status != PermissionStatus.granted && status != PermissionStatus.limited) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contacts permission denied')));
        return;
      }
      final contacts = await FlutterContacts.getAll(
          properties: {ContactProperty.phone});
      if (!mounted) return;
      final picked = await showDialog<Contact>(
        context: context,
        builder: (_) => _ContactPickerDialog(contacts: contacts),
      );
      if (picked == null || picked.phones.isEmpty) return;
      final phone = picked.phones.length == 1
          ? picked.phones.first.number
          : await showDialog<String>(
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: const Color(0xFF1a1a1a),
                title: const Text('Select Number', style: TextStyle(color: Colors.white)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: picked.phones.map((p) => ListTile(
                    title: Text(p.number, style: const TextStyle(color: Colors.white)),
                    onTap: () => Navigator.pop(context, p.number),
                  )).toList(),
                ),
              ),
            );
      if (phone == null || phone.isEmpty) return;
      final normed = _norm(phone);
      if (_recipients.any((r) => r['phone'] == normed)) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('That number is already in the list')));
        return;
      }
      setState(() => _recipients.add({
        'name':  picked.displayName ?? '',
        'phone': normed,
      }));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking contact: $e')));
    }
  }

  void _addManual() {
    final name  = _manNameCtrl.text.trim();
    final phone = _norm(_manPhoneCtrl.text.trim());
    if (name.isEmpty || phone.isEmpty || phone == '+') return;
    if (_recipients.any((r) => r['phone'] == phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That number is already in the list')));
      return;
    }
    setState(() {
      _recipients.add({'name': name, 'phone': phone});
      _manNameCtrl.clear();
      _manPhoneCtrl.clear();
      _showManual = false;
    });
  }

  Future<void> _save() async {
    final String name;
    if (_recipients.length >= 2) {
      final n = _nameCtrl.text.trim();
      if (n.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Enter a group name')));
        return;
      }
      name = n;
    } else if (_recipients.length == 1) {
      name = _recipients[0]['name']!;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add at least one recipient')));
      return;
    }

    setState(() => _saving = true);
    final db      = await DB.instance;
    final payload = {'name': name, 'message': _msgCtrl.text.trim()};
    final existing = widget.existing;
    if (existing != null) {
      final id = existing['id'] as int;
      await db.update('messages', payload, where: 'id = ?', whereArgs: [id]);
      await db.delete('message_recipients', where: 'message_id = ?', whereArgs: [id]);
      for (final r in _recipients) {
        await db.insert('message_recipients',
            {'message_id': id, 'name': r['name'], 'phone': r['phone']});
      }
    } else {
      final id = await db.insert('messages', payload);
      for (final r in _recipients) {
        await db.insert('message_recipients',
            {'message_id': id, 'name': r['name'], 'phone': r['phone']});
      }
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final multiRecipient = _recipients.length >= 2;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing != null ? 'Edit Message' : 'New Message'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save',
                    style: TextStyle(color: Color(0xFF7eb8f7), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          if (multiRecipient) ...[
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Group Name',
                hintText: 'e.g. Family, Work, Emergency',
              ),
            ),
            const SizedBox(height: 16),
          ],

          TextField(
            controller: _msgCtrl,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Message to send',
              hintText: 'What gets sent when the switch triggers…',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),

          // ── Recipients ─────────────────────────────────────────────────
          Row(children: [
            const Text('RECIPIENTS',
                style: TextStyle(color: Colors.grey, fontSize: 11,
                    fontWeight: FontWeight.w600, letterSpacing: 1.0)),
            const Spacer(),
            TextButton.icon(
              onPressed: _pickContact,
              icon: const Icon(Icons.contacts_outlined, size: 15),
              label: const Text('Contacts', style: TextStyle(fontSize: 13)),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF7eb8f7),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 4),
            TextButton.icon(
              onPressed: () => setState(() => _showManual = !_showManual),
              icon: const Icon(Icons.edit_outlined, size: 15),
              label: const Text('Manual', style: TextStyle(fontSize: 13)),
              style: TextButton.styleFrom(
                foregroundColor: _showManual
                    ? const Color(0xFFf59e0b)
                    : const Color(0xFF7eb8f7),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ]),

          if (_showManual) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF333333)),
              ),
              child: Row(children: [
                Expanded(child: TextField(
                  controller: _manNameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Name', isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                )),
                const SizedBox(width: 8),
                Expanded(child: TextField(
                  controller: _manPhoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone', isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                )),
                IconButton(
                  onPressed: _addManual,
                  icon: const Icon(Icons.add_circle, color: Color(0xFF2563eb), size: 28),
                  tooltip: 'Add',
                  padding: const EdgeInsets.only(left: 6),
                  constraints: const BoxConstraints(),
                ),
              ]),
            ),
          ],

          const SizedBox(height: 8),
          if (_recipients.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text('No recipients yet. Add from Contacts or enter manually.',
                  style: TextStyle(color: Color(0xFF555555), fontSize: 12)),
            )
          else
            ..._recipients.asMap().entries.map((e) {
              final i = e.key;
              final r = e.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF2a2a2a)),
                ),
                child: ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  title: Text(r['name']!,
                      style: const TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: Text(r['phone']!,
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Color(0xFF884444)),
                    onPressed: () => setState(() => _recipients.removeAt(i)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Remove',
                  ),
                ),
              );
            }),

        ]),
      ),
    );
  }
}

// ─── Contact Picker Dialog ────────────────────────────────────────────────────

class _ContactPickerDialog extends StatefulWidget {
  final List<Contact> contacts;
  const _ContactPickerDialog({required this.contacts});
  @override
  State<_ContactPickerDialog> createState() => _ContactPickerDialogState();
}

class _ContactPickerDialogState extends State<_ContactPickerDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.contacts
        .where((c) =>
            c.phones.isNotEmpty &&
            (c.displayName ?? '').toLowerCase().contains(_query.toLowerCase()))
        .toList();
    return Dialog(
      backgroundColor: const Color(0xFF1a1a1a),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Search contacts…',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No contacts found',
                  style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final c = filtered[i];
                    return ListTile(
                      title: Text(c.displayName ?? '',
                          style: const TextStyle(color: Colors.white)),
                      subtitle: Text(c.phones.first.number,
                          style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      onTap: () => Navigator.pop(context, c),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
