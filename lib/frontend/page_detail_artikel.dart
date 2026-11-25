import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../backend/artikel/artikel_block.dart';
import '../backend/artikel/artikel_parser.dart';
import 'artikel/widget/artikel_block_view.dart';

class PageDetailArtikel extends StatelessWidget {
  final String artikelId;
  final Map<String, dynamic> data;

  const PageDetailArtikel({
    super.key,
    required this.artikelId,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final String judul = (data['judul'] ?? 'Tanpa Judul').toString();
    final String? gambarUrl = ArtikelParser.bersihkanUrl(data['gambarUrl']);
    final DateTime? dibuat = ArtikelParser.toDate(data['dibuatPada']);
    final DateTime? diupdate = ArtikelParser.toDate(data['diupdatePada']);
    final List<ArtikelBlock> konten = ArtikelParser.kontenDariDoc(data);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          judul,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (gambarUrl != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    gambarUrl,
                    width: double.infinity,
                    height: 140,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      height: 140,
                      color: Colors.grey[200],
                      child: const Center(
                        child: Icon(Icons.broken_image_outlined, size: 40, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    judul,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        dibuat == null
                            ? 'Tanggal tidak tersedia'
                            : 'Dipublikasikan: ${DateFormat('dd MMM yyyy').format(dibuat)}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  if (diupdate != null && (dibuat == null || !diupdate.isAtSameMomentAs(dibuat))) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Diperbarui: ${DateFormat('dd MMM yyyy, HH:mm').format(diupdate)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                  const Divider(height: 28),
                  if (konten.isEmpty)
                    const SelectableText(
                      'Isi artikel kosong.',
                      style: TextStyle(fontSize: 15, height: 1.6, color: Colors.black87),
                    )
                  else
                    ...konten.map((block) => ArtikelBlockView(block: block)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
