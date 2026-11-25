import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../backend/artikel/artikel_parser.dart';

// =========================================================================
// WIDGET: KARTU ARTIKEL (THUMBNAIL COVER)
// =========================================================================
class ArtikelCard extends StatelessWidget {
  final String artikelId;
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const ArtikelCard({
    super.key,
    required this.artikelId,
    required this.data,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String judul = (data['judul'] ?? 'Tanpa Judul').toString();
    final String isiRaw = (data['isi'] ?? '').toString().replaceAll('\n', ' ');
    final String excerpt = isiRaw.length > 120 ? '${isiRaw.substring(0, 120)}...' : isiRaw;
    final String? gambarUrl = ArtikelParser.bersihkanUrl(data['gambarUrl']);
    final DateTime? tanggal = ArtikelParser.toDate(data['dibuatPada']);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 96,
              height: 96,
              color: Colors.grey[200],
              child: gambarUrl == null
                  ? const Center(child: Icon(Icons.article_outlined, color: Colors.grey))
                  : Image.network(
                      gambarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Center(
                        child: Icon(Icons.broken_image_outlined, color: Colors.grey),
                      ),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      judul,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                    if (excerpt.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        excerpt,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          tanggal == null ? '-' : DateFormat('dd MMM yyyy').format(tanggal),
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 8, top: 38),
              child: Icon(Icons.chevron_right, size: 18, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
