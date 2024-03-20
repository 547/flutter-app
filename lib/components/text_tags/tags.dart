import 'package:flutter/material.dart';

class TextTags extends StatelessWidget {
  final List<String> tags;
  const TextTags({Key? key, required this.tags}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: tags.map((tag) {
        return Container(
          margin: const EdgeInsets.only(right: 10),
          child: Text(
            tag,
            style: const TextStyle(
              fontSize: 12,
            ),
          ),
        );
      }).toList(),
    );
  }
}
