import 'package:flutter/material.dart';

// =========================================================================
// WIDGET: FIELD JUDUL ARTIKEL
// =========================================================================
class EditorJudulField extends StatelessWidget {
  final String initialValue;
  final ValueChanged<String> onChanged;

  const EditorJudulField({
    super.key,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        labelText: "Judul Artikel",
        border: OutlineInputBorder(),
      ),
      onChanged: onChanged,
    );
  }
}
