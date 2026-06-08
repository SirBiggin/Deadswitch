import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../db/database.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});
  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  List<Map<String, dynamic>> _groups = [];
  Map<int, List<String>> _groupMembers = {};

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final db = await DB.instance;
    final groups = await db.query('message_groups', orderBy: 'name');
    final Map<int, List<String>> members = {};
    for (final g in groups) {
      final gid = g['id'] as int;
      final rows = await db.query('group_recipients',
          columns: ['name'], where: 'group_id = ?', whereArgs: [gid]);
      members[gid] = rows.map((r) => r['name'] as String).toList();
    }
    setState(() { _groups = groups; _groupMembers = members; });
  }

  Future<void> _delete(int id, String name) async {
    final ok = await showDialog<bool>(context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1a1a1a),
          title: const Text('Delete group', style: TextStyle(color: Colors.white)),
          content: Text('Delete "$name"?', style: const TextStyle(color: Colors.grey)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete', style: TextStyle(color: Color(0xFFc87e7e)))),
          ],
        ));
    if (ok != true) return;
    final db = await DB.instance;
    await db.delete('message_groups', where: 'id = ?', whereArgs: [id]);
    await db.delete('group_recipients', where: 'group_id = ?', whereArgs: [id]);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _groups.isEmpty
          ? const Center(child: Text('No groups yet.',
              style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              itemCount: _groups.length,
              padding: const EdgeInsets.all(12),
              itemBuilder: (_, i) {
                final g = _groups[i];
                final gid = g['id'] as int;
                final members = _groupMembers[gid] ?? [];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(g['name'] as String,
                            style: const TextStyle(color: Colors.white,
                                fontWeight: FontWeight.w700, fontSize: 15))),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18, color: Colors.grey),
                          onPressed: () => Navigator.push(context,
                              MaterialPageRoute(
                                  builder: (_) => GroupFormScreen(id: gid)))
                              .then((_) => _load()),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 18,
                              color: Color(0xFFc87e7e)),
                          onPressed: () => _delete(gid, g['name'] as String),
                        ),
                      ]),
                      Container(
                        margin: const EdgeInsets.only(top: 6, bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111111),
                          border: Border.all(color: const Color(0xFF222222)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(g['message'] as String,
                            style: const TextStyle(color: Color(0xFFaaaaaa), fontSize: 13)),
                      ),
                      members.isNotEmpty
                          ? Text('Recipients: ${members.join(", ")}',
                              style: const TextStyle(color: Colors.grey, fontSize: 12))
                          : const Text('No recipients assigned.',
                              style: TextStyle(color: Color(0xFF444444), fontSize: 12)),
                    ]),
                  ),
                );
              }),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const GroupFormScreen()))
            .then((_) => _load()),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// Represents a phone contact selected for a group
class _Recipient {
  final String name;
  final String phone;
  _Recipient(this.name, this.phone);
}

class GroupFormScreen extends StatefulWidget {
  final int? id;
  const GroupFormScreen({super.key, this.id});
  @override
  State<GroupFormScreen> createState() => _GroupFormScreenState();
}

class _GroupFormScreenState extends State<GroupFormScreen> {
  final _nameCtrl    = TextEditingController();
  final _messageCtrl = TextEditingController();
  List<_Recipient> _recipients = [];
  bool _saving = false;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.id == null) return;
    final db = await DB.instance;
    final rows = await db.query('message_groups',
        where: 'id = ?', whereArgs: [widget.id]);
    if (rows.isNotEmpty) {
      _nameCtrl.text    = rows.first['name']    as String;
      _messageCtrl.text = rows.first['message'] as String;
    }
    final recs = await db.query('group_recipients',
        where: 'group_id = ?', whereArgs: [widget.id]);
    setState(() {
      _recipients = recs.map((r) =>
          _Recipient(r['name'] as String, r['phone'] as String)).toList();
    });
  }

  Future<void> _pickContacts() async {
    try {
      await FlutterContacts.permissions.request(PermissionType.read);
      if (!mounted) return;
      final contacts = await FlutterContacts.getAll(
          properties: {ContactProperty.phone});
      if (!mounted) return;
      final result = await Navigator.push<List<_Recipient>>(
        context,
        MaterialPageRoute(
          builder: (_) => _MultiContactPickerScreen(
            contacts: contacts,
            preSelected: _recipients,
          ),
        ),
      );
      if (result != null) setState(() => _recipients = result);
    } catch (_) {}
  }

  Future<void> _save() async {
    final name    = _nameCtrl.text.trim();
    final message = _messageCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a group name')));
      return;
    }
    setState(() => _saving = true);
    final db = await DB.instance;
    int id;
    if (widget.id == null) {
      id = await db.insert('message_groups', {'name': name, 'message': message});
    } else {
      id = widget.id!;
      await db.update('message_groups', {'name': name, 'message': message},
          where: 'id = ?', whereArgs: [id]);
      await db.delete('group_recipients', where: 'group_id = ?', whereArgs: [id]);
    }
    for (final r in _recipients) {
      await db.insert('group_recipients', {
        'group_id': id,
        'name': r.name,
        'phone': r.phone,
      });
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.id == null ? 'New Group' : 'Edit Group'),
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: _saving ? null : _save),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Group Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _messageCtrl,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Message',
              hintText: 'Message sent to all recipients in this group',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),
          Row(children: [
            const Text('RECIPIENTS', style: TextStyle(color: Colors.grey,
                fontSize: 11, letterSpacing: 1.2)),
            const Spacer(),
            TextButton.icon(
              onPressed: _pickContacts,
              icon: const Icon(Icons.person_add, size: 16),
              label: Text(_recipients.isEmpty ? 'Select' : 'Edit'),
            ),
          ]),
          const SizedBox(height: 8),
          if (_recipients.isEmpty)
            const Text('No recipients selected.',
                style: TextStyle(color: Color(0xFF555555), fontSize: 13))
          else
            ..._recipients.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                const Icon(Icons.person, color: Color(0xFF2563eb), size: 16),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(r.name, style: const TextStyle(color: Colors.white, fontSize: 14)),
                  Text(r.phone, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ])),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => setState(() => _recipients.remove(r)),
                ),
              ]),
            )),
        ]),
      ),
    );
  }
}

class _MultiContactPickerScreen extends StatefulWidget {
  final List<Contact> contacts;
  final List<_Recipient> preSelected;
  const _MultiContactPickerScreen({required this.contacts, required this.preSelected});
  @override
  State<_MultiContactPickerScreen> createState() => _MultiContactPickerScreenState();
}

class _MultiContactPickerScreenState extends State<_MultiContactPickerScreen> {
  String _query = '';
  late Set<String> _selectedPhones;
  late List<_Recipient> _manualEntries;
  late Map<String, Contact> _phoneMap;

  @override
  void initState() {
    super.initState();
    _phoneMap = {};
    for (final c in widget.contacts) {
      for (final p in c.phones) {
        _phoneMap[p.number] = c;
      }
    }
    _selectedPhones = {};
    _manualEntries = [];
    for (final r in widget.preSelected) {
      if (_phoneMap.containsKey(r.phone)) {
        _selectedPhones.add(r.phone);
      } else {
        _manualEntries.add(r);
      }
    }
  }

  List<Contact> get _filtered {
    final q = _query.toLowerCase();
    return widget.contacts
        .where((c) =>
            c.phones.isNotEmpty &&
            (q.isEmpty ||
                (c.displayName ?? '').toLowerCase().contains(q) ||
                c.phones.any((p) => p.number.contains(q))))
        .toList();
  }

  void _toggle(Contact c) {
    final phone = c.phones.first.number;
    setState(() {
      if (_selectedPhones.contains(phone)) {
        _selectedPhones.remove(phone);
      } else {
        _selectedPhones.add(phone);
      }
    });
  }

  Future<void> _addManually() async {
    final result = await showDialog<_Recipient>(
      context: context,
      builder: (_) => const _ManualRecipientDialog(),
    );
    if (result != null) setState(() => _manualEntries.add(result));
  }

  void _done() {
    final result = <_Recipient>[..._manualEntries];
    for (final phone in _selectedPhones) {
      final c = _phoneMap[phone];
      if (c == null) continue;
      final dn = c.displayName ?? '';
      final name = dn.isNotEmpty ? dn
          : '${c.name?.first ?? ''} ${c.name?.last ?? ''}'.trim();
      result.add(_Recipient(name, phone));
    }
    Navigator.pop(context, result);
  }

  int get _totalSelected => _selectedPhones.length + _manualEntries.length;

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: Text(_totalSelected == 0
            ? 'Select Recipients'
            : '$_totalSelected selected'),
        actions: [
          TextButton(
            onPressed: _done,
            child: const Text('Done', style: TextStyle(color: Colors.white,
                fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: TextField(
            autofocus: false,
            decoration: const InputDecoration(
              hintText: 'Search contacts...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        // Manual entry button
        InkWell(
          onTap: _addManually,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563eb).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.edit, color: Color(0xFF2563eb), size: 18),
              ),
              const SizedBox(width: 12),
              const Text('Add manually (name + number)',
                  style: TextStyle(color: Color(0xFF2563eb), fontSize: 14)),
            ]),
          ),
        ),
        // Manually added entries
        if (_manualEntries.isNotEmpty) ...[
          const Divider(color: Color(0xFF222222), height: 1),
          ..._manualEntries.map((r) => ListTile(
            leading: const Icon(Icons.person_outline, color: Color(0xFF2563eb)),
            title: Text(r.name, style: const TextStyle(color: Colors.white)),
            subtitle: Text(r.phone,
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            trailing: IconButton(
              icon: const Icon(Icons.close, color: Colors.grey, size: 18),
              onPressed: () => setState(() => _manualEntries.remove(r)),
            ),
          )),
        ],
        const Divider(color: Color(0xFF222222), height: 1),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No contacts found',
                  style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final c = filtered[i];
                    final phone = c.phones.first.number;
                    final selected = _selectedPhones.contains(phone);
                    return CheckboxListTile(
                      value: selected,
                      onChanged: (_) => _toggle(c),
                      activeColor: const Color(0xFF2563eb),
                      title: Text(c.displayName ?? '',
                          style: const TextStyle(color: Colors.white)),
                      subtitle: Text(phone,
                          style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

class _ManualRecipientDialog extends StatefulWidget {
  const _ManualRecipientDialog();
  @override
  State<_ManualRecipientDialog> createState() => _ManualRecipientDialogState();
}

class _ManualRecipientDialogState extends State<_ManualRecipientDialog> {
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();

  @override
  void dispose() { _nameCtrl.dispose(); _phoneCtrl.dispose(); super.dispose(); }

  void _submit() {
    final name  = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) return;
    Navigator.pop(context, _Recipient(name, phone));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1a1a1a),
      title: const Text('Add Manually', style: TextStyle(color: Colors.white)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: _nameCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (_) => FocusScope.of(context).nextFocus(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Phone number'),
          onSubmitted: (_) => _submit(),
        ),
      ]),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text('Add', style: TextStyle(color: Color(0xFF2563eb),
              fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
