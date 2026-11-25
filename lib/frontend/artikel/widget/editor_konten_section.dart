import 'package:flutter/material.dart';

import '../../../backend/artikel/artikel_block.dart';
import 'editor_block_tile.dart';

class EditorKontenSection extends StatelessWidget {
  final List<ArtikelBlock> blocks;
  final void Function(int index, String value) onTextChanged;
  final void Function(int index, String value) onCaptionChanged;
  final void Function(int index) onDelete;
  final void Function(int index) onMoveUp;
  final void Function(int index) onMoveDown;

  const EditorKontenSection({
    super.key,
    required this.blocks,
    required this.onTextChanged,
    required this.onCaptionChanged,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Konten Artikel", style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        for (int i = 0; i < blocks.length; i++)
          EditorBlockTile(
            block: blocks[i],
            index: i,
            total: blocks.length,
            onTextChanged: (value) => onTextChanged(i, value),
            onCaptionChanged: (value) => onCaptionChanged(i, value),
            onDelete: () => onDelete(i),
            onMoveUp: () => onMoveUp(i),
            onMoveDown: () => onMoveDown(i),
          ),
      ],
    );
  }
}
