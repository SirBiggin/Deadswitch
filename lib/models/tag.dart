class Tag {
  final int? id;
  final String name;
  Tag({this.id, required this.name});
  factory Tag.fromMap(Map<String, dynamic> m) => Tag(id: m['id'], name: m['name']);
  Map<String, dynamic> toMap() => {'name': name};
}
