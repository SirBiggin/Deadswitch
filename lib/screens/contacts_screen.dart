import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:sqflite/sqflite.dart';
import '../db/database.dart';
import '../widgets/tag_chips.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});
  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _tags = [];
  String? _filterTag;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final db = await DB.instance;
    final contacts = await db.rawQuery('''
      SELECT c.*, GROUP_CONCAT(t.name, '|||') as tag_names
      FROM contacts c
      LEFT JOIN contact_tags ct ON ct.contact_id = c.id
      LEFT JOIN tags t ON t.id = ct.tag_id
      GROUP BY c.id ORDER BY c.name''');
    final tags = await db.query('tags', orderBy: 'name');
    setState(() { _contacts = contacts; _tags = tags; });
  }

  Future<void> _delete(int id, String name) async {
    final ok = await showDialog<bool>(context: context,
        builder: (_) => AlertDialog(
          title: const Text('Delete contact'),
          content: Text('Delete $name?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete', style: TextStyle(color: Colors.red))),
          ],
        ));
    if (ok != true) return;
    final db = await DB.instance;
    await db.delete('contacts', where: 'id = ?', whereArgs: [id]);
    await db.delete('contact_tags', where: 'contact_id = ?', whereArgs: [id]);
    _load();
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filterTag == null) return _contacts;
    return _contacts.where((c) {
      final tags = (c['tag_names'] as String? ?? '').split('|||');
      return tags.contains(_filterTag);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [
        if (_tags.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              _filterChip('All', _filterTag == null, () => setState(() => _filterTag = null)),
              ..._tags.map((t) => _filterChip(t['name'] as String, _filterTag == t['name'],
                  () => setState(() => _filterTag = t['name'] as String))),
            ]),
          ),
        Expanded(
          child: _filtered.isEmpty
              ? const Center(child: Text('No contacts.', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final c = _filtered[i];
                    final tagNames = (c['tag_names'] as String? ?? '').split('|||')
                        .where((s) => s.isNotEmpty).toList();
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: ListTile(
                        title: Text(c['name'] as String,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(c['phone'] as String, style: const TextStyle(color: Colors.grey)),
                          if (tagNames.isNotEmpty) TagChips(tags: tagNames),
                          if ((c['message'] as String).isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(c['message'] as String,
                                  style: const TextStyle(color: Color(0xFFaaaaaa), fontSize: 12)),
                            ),
                        ]),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(icon: const Icon(Icons.edit, size: 18), color: Colors.grey,
                              onPressed: () => Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => ContactFormScreen(id: c['id'] as int)))
                                  .then((_) => _load())),
                          IconButton(icon: const Icon(Icons.delete, size: 18), color: const Color(0xFFc87e7e),
                              onPressed: () => _delete(c['id'] as int, c['name'] as String)),
                        ]),
                      ),
                    );
                  }),
        ),
      ]),
      floatingActionButton: Column(mainAxisSize: MainAxisSize.min, children: [
        FloatingActionButton.small(
          heroTag: 'import',
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ContactImportScreen())).then((_) => _load()),
          child: const Icon(Icons.phone_android),
        ),
        const SizedBox(height: 8),
        FloatingActionButton(
          heroTag: 'add',
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ContactFormScreen())).then((_) => _load()),
          child: const Icon(Icons.add),
        ),
      ]),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF1e3a5f) : const Color(0xFF222222),
            border: Border.all(color: selected ? const Color(0xFF2a5a8f) : const Color(0xFF333333)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label, style: TextStyle(
              fontSize: 12, color: selected ? const Color(0xFF7eb8f7) : Colors.grey)),
        ),
      ),
    );
  }
}

class ContactFormScreen extends StatefulWidget {
  final int? id;
  const ContactFormScreen({super.key, this.id});
  @override
  State<ContactFormScreen> createState() => _ContactFormScreenState();
}

class _ContactFormScreenState extends State<ContactFormScreen> {
  final _nameCtrl    = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _messageCtrl = TextEditingController();
  List<Map<String, dynamic>> _allTags = [];
  Set<int> _selectedTagIds = {};

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final db = await DB.instance;
    final tags = await db.query('tags', orderBy: 'name');
    if (widget.id != null) {
      final rows = await db.query('contacts', where: 'id = ?', whereArgs: [widget.id]);
      if (rows.isNotEmpty) {
        _nameCtrl.text    = rows.first['name'] as String;
        _phoneCtrl.text   = rows.first['phone'] as String;
        _messageCtrl.text = rows.first['message'] as String;
      }
      final ct = await db.query('contact_tags', where: 'contact_id = ?', whereArgs: [widget.id]);
      _selectedTagIds = ct.map((r) => r['tag_id'] as int).toSet();
    }
    setState(() => _allTags = tags);
  }

  Future<void> _save() async {
    final name  = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) return;
    final db = await DB.instance;
    int id;
    if (widget.id == null) {
      id = await db.insert('contacts', {'name': name, 'phone': phone, 'message': _messageCtrl.text.trim()});
    } else {
      id = widget.id!;
      await db.update('contacts', {'name': name, 'phone': phone, 'message': _messageCtrl.text.trim()},
          where: 'id = ?', whereArgs: [id]);
      await db.delete('contact_tags', where: 'contact_id = ?', whereArgs: [id]);
    }
    for (final tid in _selectedTagIds) {
      await db.insert('contact_tags', {'contact_id': id, 'tag_id': tid},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _addNewTag(String name) async {
    if (name.isEmpty) return;
    final db = await DB.instance;
    final id = await db.insert('tags', {'name': name.toLowerCase().trim()},
        conflictAlgorithm: ConflictAlgorithm.ignore);
    final row = await db.query('tags', where: 'name = ?', whereArgs: [name.toLowerCase().trim()]);
    if (row.isNotEmpty) _selectedTagIds.add(row.first['id'] as int);
    setState(() => _allTags = _allTags);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.id == null ? 'Add Contact' : 'Edit Contact'),
          actions: [IconButton(icon: const Icon(Icons.check), onPressed: _save)]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Full Name')),
          const SizedBox(height: 12),
          TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone Number')),
          const SizedBox(height: 12),
          TextField(controller: _messageCtrl, maxLines: 4,
              decoration: const InputDecoration(labelText: 'Message (optional)')),
          const SizedBox(height: 16),
          const Text('Tags', style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, children: [
            ..._allTags.map((t) {
              final selected = _selectedTagIds.contains(t['id'] as int);
              return GestureDetector(
                onTap: () => setState(() {
                  if (selected) _selectedTagIds.remove(t['id'] as int);
                  else _selectedTagIds.add(t['id'] as int);
                }),
                child: _tagChip(t['name'] as String, selected),
              );
            }),
            GestureDetector(
              onTap: () async {
                final ctrl = TextEditingController();
                await showDialog(context: context, builder: (_) => AlertDialog(
                  title: const Text('New tag'),
                  content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Tag name')),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    TextButton(onPressed: () { Navigator.pop(context); _addNewTag(ctrl.text); },
                        child: const Text('Add')),
                  ],
                ));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF222222),
                  border: Border.all(color: const Color(0xFF333333), style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('+ New tag', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _tagChip(String label, bool selected) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: selected ? const Color(0xFF1e3a5f) : const Color(0xFF222222),
      border: Border.all(color: selected ? const Color(0xFF2a5a8f) : const Color(0xFF333333)),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label, style: TextStyle(fontSize: 12,
        color: selected ? const Color(0xFF7eb8f7) : Colors.grey)),
  );
}

class ContactImportScreen extends StatefulWidget {
  const ContactImportScreen({super.key});
  @override
  State<ContactImportScreen> createState() => _ContactImportScreenState();
}

class _ContactImportScreenState extends State<ContactImportScreen> {
  List<Contact> _phoneContacts = [];
  final Set<String> _selectedIds = {};
  final _messageCtrl = TextEditingController();
  String _search = '';
  bool _loading = false;
  List<Map<String, dynamic>> _allTags = [];
  final Set<int> _selectedTagIds = {};

  @override
  void initState() { super.initState(); _loadTags(); }

  Future<void> _loadTags() async {
    final db = await DB.instance;
    final tags = await db.query('tags', orderBy: 'name');
    setState(() => _allTags = tags);
  }

  Future<void> _loadContacts() async {
    setState(() => _loading = true);
    final status = await FlutterContacts.permissions.request(PermissionType.read);
    if (status == PermissionStatus.granted || status == PermissionStatus.limited) {
      final contacts = await FlutterContacts.getAll(
          properties: {ContactProperty.phone});
      setState(() { _phoneContacts = contacts; _loading = false; });
    } else {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contacts permission denied')));
    }
  }

  Future<void> _import() async {
    final selected = _phoneContacts.where((c) => _selectedIds.contains(c.id ?? '')).toList();
    if (selected.isEmpty) return;
    final db = await DB.instance;
    for (final c in selected) {
      final phone = c.phones.isNotEmpty ? c.phones.first.number : '';
      if (phone.isEmpty) continue;
      final id = await db.insert('contacts',
          {'name': c.displayName ?? '', 'phone': phone, 'message': _messageCtrl.text.trim()});
      for (final tid in _selectedTagIds) {
        await db.insert('contact_tags', {'contact_id': id, 'tag_id': tid},
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }
    if (mounted) Navigator.pop(context);
  }

  List<Contact> get _filtered => _phoneContacts.where((c) {
    final q = _search.toLowerCase();
    final name = (c.displayName ?? '').toLowerCase();
    return name.contains(q) ||
        c.phones.any((p) => p.number.contains(q));
  }).toList();

  @override
  Widget build(BuildContext context) {
    final selCount = _selectedIds.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(selCount > 0 ? 'Import Contacts ($selCount)' : 'Import Contacts'),
        actions: [if (_selectedIds.isNotEmpty)
          IconButton(icon: const Icon(Icons.check), onPressed: _import)],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            if (_phoneContacts.isEmpty)
              SizedBox(width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _loadContacts,
                  icon: _loading ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.phone_android),
                  label: Text(_loading ? 'Loading...' : 'Load from Phone'),
                )),
            if (_phoneContacts.isNotEmpty) ...[
              Row(children: [
                Expanded(child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: const InputDecoration(hintText: 'Search...', prefixIcon: Icon(Icons.search)),
                )),
                const SizedBox(width: 8),
                TextButton(onPressed: () => setState(() =>
                    _selectedIds.addAll(_filtered.map((c) => c.id ?? '').where((s) => s.isNotEmpty))),
                    child: const Text('All')),
                TextButton(onPressed: () => setState(() => _selectedIds.clear()), child: const Text('None')),
              ]),
            ],
            const SizedBox(height: 8),
            TextField(controller: _messageCtrl, maxLines: 2,
                decoration: const InputDecoration(labelText: 'Message (optional)')),
            if (_allTags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerLeft,
                  child: Wrap(spacing: 6, children: _allTags.map((t) {
                    final sel = _selectedTagIds.contains(t['id'] as int);
                    return GestureDetector(
                      onTap: () => setState(() {
                        if (sel) _selectedTagIds.remove(t['id'] as int);
                        else _selectedTagIds.add(t['id'] as int);
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: sel ? const Color(0xFF1e3a5f) : const Color(0xFF222222),
                          border: Border.all(color: sel ? const Color(0xFF2a5a8f) : const Color(0xFF333333)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(t['name'] as String,
                            style: TextStyle(fontSize: 11,
                                color: sel ? const Color(0xFF7eb8f7) : Colors.grey)),
                      ),
                    );
                  }).toList())),
            ],
          ]),
        ),
        Expanded(child: ListView.builder(
          itemCount: _filtered.length,
          itemBuilder: (_, i) {
            final c = _filtered[i];
            final cid = c.id ?? '';
            final sel = cid.isNotEmpty && _selectedIds.contains(cid);
            return CheckboxListTile(
              value: sel,
              onChanged: cid.isEmpty ? null : (_) => setState(() {
                if (sel) _selectedIds.remove(cid); else _selectedIds.add(cid);
              }),
              title: Text(c.displayName ?? '(no name)', style: const TextStyle(color: Colors.white)),
              subtitle: Text(c.phones.isNotEmpty ? c.phones.first.number : 'No number',
                  style: const TextStyle(color: Colors.grey)),
              activeColor: const Color(0xFF2563eb),
            );
          },
        )),
      ]),
    );
  }
}
