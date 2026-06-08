import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../db/database.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<Map<String, dynamic>> _messages = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final db = await DB.instance;
    final rows = await db.query('contacts', orderBy: 'name ASC');
    setState(() => _messages = rows);
  }

  Future<void> _delete(int id) async {
    final db = await DB.instance;
    await db.delete('contacts', where: 'id = ?', whereArgs: [id]);
    _load();
  }

  void _openForm([Map<String, dynamic>? existing]) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => MessageFormScreen(existing: existing),
    )).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Individual Messages'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: () => _openForm()),
        ],
      ),
      body: _messages.isEmpty
          ? const Center(
              child: Text('No messages yet.\nTap + to create one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 14)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final m = _messages[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(m['name'] as String,
                              style: const TextStyle(color: Colors.white,
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 2),
                          Text(m['phone'] as String,
                              style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 6),
                          Text(m['message'] as String,
                              style: const TextStyle(color: Color(0xFFaaaaaa), fontSize: 13),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                        ]),
                      ),
                      Column(children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.grey, size: 20),
                          onPressed: () => _openForm(m),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Color(0xFFc87e7e), size: 20),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                backgroundColor: const Color(0xFF1a1a1a),
                                title: const Text('Delete message?',
                                    style: TextStyle(color: Colors.white)),
                                content: Text('To: ${m["name"]}',
                                    style: const TextStyle(color: Colors.grey)),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Cancel')),
                                  TextButton(onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Delete',
                                          style: TextStyle(color: Color(0xFFc87e7e)))),
                                ],
                              ),
                            );
                            if (ok == true) _delete(m['id'] as int);
                          },
                        ),
                      ]),
                    ]),
                  ),
                );
              },
            ),
    );
  }
}

class MessageFormScreen extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const MessageFormScreen({super.key, this.existing});
  @override
  State<MessageFormScreen> createState() => _MessageFormScreenState();
}

class _MessageFormScreenState extends State<MessageFormScreen> {
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _msgCtrl   = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _nameCtrl.text  = widget.existing!['name']    as String? ?? '';
      _phoneCtrl.text = widget.existing!['phone']   as String? ?? '';
      _msgCtrl.text   = widget.existing!['message'] as String? ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickContact() async {
    try {
      await FlutterContacts.permissions.request(PermissionType.read);
      if (!mounted) return;
      final contacts = await FlutterContacts.getAll(properties: {ContactProperty.phone});
      if (!mounted) return;
      final picked = await showDialog<Contact>(
        context: context,
        builder: (_) => _ContactPickerDialog(contacts: contacts),
      );
      if (picked != null && picked.phones.isNotEmpty) {
        final dn = picked.displayName ?? '';
        _nameCtrl.text  = dn.isNotEmpty ? dn
            : '${picked.name?.first ?? ''} ${picked.name?.last ?? ''}'.trim();
        _phoneCtrl.text = picked.phones.first.number;
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    final name  = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a recipient name')));
      return;
    }
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a phone number')));
      return;
    }
    if (_msgCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message cannot be empty')));
      return;
    }
    setState(() => _saving = true);
    final db = await DB.instance;
    final data = {
      'name':    name,
      'phone':   phone,
      'message': _msgCtrl.text.trim(),
    };
    if (widget.existing != null) {
      await db.update('contacts', data,
          where: 'id = ?', whereArgs: [widget.existing!['id']]);
    } else {
      await db.insert('contacts', data);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New Message' : 'Edit Message'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('RECIPIENT', style: TextStyle(color: Colors.grey, fontSize: 11,
              letterSpacing: 1.2)),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Phone number',
              suffixIcon: IconButton(
                icon: const Icon(Icons.person_search, color: Colors.grey),
                tooltip: 'Pick from contacts',
                onPressed: _pickContact,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('MESSAGE', style: TextStyle(color: Colors.grey, fontSize: 11,
              letterSpacing: 1.2)),
          const SizedBox(height: 8),
          TextField(
            controller: _msgCtrl,
            maxLines: 7,
            decoration: const InputDecoration(
              hintText: 'What should this person receive if you go silent?',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563eb),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: Text(widget.existing == null ? 'Save Message' : 'Update Message',
                  style: const TextStyle(color: Colors.white, fontSize: 15)),
            ),
          ),
        ]),
      ),
    );
  }
}

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
            (c.displayName ?? '').toLowerCase().contains(_query.toLowerCase()) &&
            c.phones.isNotEmpty)
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
              hintText: 'Search contacts...',
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
