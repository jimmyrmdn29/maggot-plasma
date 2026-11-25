import 'package:flutter/material.dart';

import '../../../backend/artikel/artikel_block.dart';

class EditorBlockTile extends StatelessWidget {
  final ArtikelBlock block;
  final int index;
  final int total;
  final ValueChanged<String> onTextChanged;
  final ValueChanged<String> onCaptionChanged;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  const EditorBlockTile({
    super.key,
    required this.block,
    required this.index,
    required this.total,
    required this.onTextChanged,
    required this.onCaptionChanged,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  block.isTeks ? "Blok Teks" : "Blok Gambar",
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const Spacer(),
                IconButton(
                  tooltip: "Naik",
                  icon: const Icon(Icons.arrow_upward, size: 18),
                  onPressed: index > 0 ? onMoveUp : null,
                ),
                IconButton(
                  tooltip: "Turun",
                  icon: const Icon(Icons.arrow_downward, size: 18),
                  onPressed: index < total - 1 ? onMoveDown : null,
                ),
                IconButton(
                  tooltip: "Hapus blok",
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  onPressed: onDelete,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (block.isTeks)
              TextFormField(
                initialValue: block.nilai,
                minLines: 3,
                maxLines: 10,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: "Isi paragraf",
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                onChanged: onTextChanged,
              )
            else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  block.nilai,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    height: 120,
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.broken_image_outlined, color: Colors.grey),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: block.caption ?? '',
                minLines: 1,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: "Caption (opsional)",
                  border: OutlineInputBorder(),
                ),
                onChanged: onCaptionChanged,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
