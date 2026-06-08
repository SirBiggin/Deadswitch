import 'package:flutter/material.dart';

class TagChips extends StatelessWidget {
  final List<String> tags;
  const TagChips({super.key, required this.tags});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      children: tags.map((t) => Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF1e3a5f),
          border: Border.all(color: const Color(0xFF2a5a8f)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(t, style: const TextStyle(fontSize: 10, color: Color(0xFF7eb8f7))),
      )).toList(),
    );
  }
}
