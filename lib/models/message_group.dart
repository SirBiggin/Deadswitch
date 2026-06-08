class MessageGroup {
  final int? id;
  final String name;
  final String message;
  List<Contact> contacts;

  MessageGroup({this.id, required this.name, required this.message, this.contacts = const []});

  factory MessageGroup.fromMap(Map<String, dynamic> m) =>
      MessageGroup(id: m['id'], name: m['name'], message: m['message']);

  Map<String, dynamic> toMap() => {'name': name, 'message': message};
}

class Contact {
  final int? id;
  final String name;
  final String phone;
  Contact({this.id, required this.name, required this.phone});
}
