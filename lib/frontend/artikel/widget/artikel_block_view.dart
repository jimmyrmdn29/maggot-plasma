import 'package:flutter/material.dart';

import '../../../backend/artikel/artikel_block.dart';

// =========================================================================
// WIDGET: RENDER SATU BLOK ARTIKEL
// =========================================================================
class ArtikelBlockView extends StatelessWidget {
  final ArtikelBlock block;

  const ArtikelBlockView({super.key, required this.block});

  @override
  Widget build(BuildContext context) {
    if (block.isTeks) {
      final String text = block.nilai.trim();
      if (text.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SelectableText(
          text,
          style: const TextStyle(fontSize: 15, height: 1.6, color: Colors.black87),
        ),
      );
    }

    if (block.isGambar) {
      final String url = block.nilai.trim();
      if (url.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      url,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(Icons.broken_image_outlined, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (block.caption != null && block.caption!.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                block.caption!,
                style: const TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: Colors.black54,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
