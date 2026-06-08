class Contact {
  final int? id;
  final String name;
  final String phone;
  final String message;
  List<String> tags;

  Contact({this.id, required this.name, required this.phone, this.message = '', this.tags = const []});

  factory Contact.fromMap(Map<String, dynamic> m) => Contact(
    id: m['id'], name: m['name'], phone: m['phone'], message: m['message'] ?? '');

  Map<String, dynamic> toMap() => {'name': name, 'phone': phone, 'message': message};
}
