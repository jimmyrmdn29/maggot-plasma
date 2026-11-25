import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../backend/artikel/artikel_repository.dart';
import '../backend/artikel/artikel_parser.dart';
import 'artikel/konfirmasi_hapus_artikel.dart';
import 'artikel/page_editor_artikel.dart';

// =========================================================================
// 1. WIDGET UTAMA (PANEL ADMIN - KELOLA ARTIKEL)
// =========================================================================
class PageKelolaArtikel extends StatefulWidget {
  const PageKelolaArtikel({super.key});

  @override
  State<PageKelolaArtikel> createState() => _PageKelolaArtikelState();
}

class _PageKelolaArtikelState extends State<PageKelolaArtikel> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = ArtikelRepository.streamArtikel();
  }

  Future<void> _bukaEditor({String? id, required Map<String, dynamic> data}) async {
    final bool? hasil = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PageEditorArtikel(
          artikelId: id,
          judulAwal: (data['judul'] ?? '').toString(),
          coverAwal: (data['gambarUrl'] ?? '').toString(),
          kontenAwal: ArtikelParser.kontenDariDoc(data),
        ),
      ),
    );

    if (!mounted) return;
    if (hasil == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Artikel berhasil disimpan."),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _hapusArtikel(String id, String judul) async {
    final bool konfirmasi = await tampilkanKonfirmasiHapusArtikel(context, judul: judul);
    if (!konfirmasi) return;

    try {
      await ArtikelRepository.hapusArtikel(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Artikel berhasil dihapus."),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Gagal menghapus artikel: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  "Gagal memuat artikel: ${snapshot.error}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? const [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.article_outlined, size: 70, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  const Text(
                    "Belum ada artikel.",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Tekan tombol + untuk menambah artikel baru.",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final String judul = (data['judul'] ?? 'Tanpa Judul').toString();
              final String isiRaw = (data['isi'] ?? '').toString().replaceAll('\n', ' ');
              final String excerpt = isiRaw.length > 120
                  ? '${isiRaw.substring(0, 120)}...'
                  : isiRaw;
              final DateTime? tanggal = ArtikelParser.toDate(data['diupdatePada'] ?? data['dibuatPada']);

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              judul,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: "Edit Artikel",
                            icon: const Icon(Icons.edit_outlined, color: Color(0xFF1A237E)),
                            onPressed: () => _bukaEditor(
                              id: doc.id,
                              data: data,
                            ),
                          ),
                          IconButton(
                            tooltip: "Hapus Artikel",
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _hapusArtikel(doc.id, judul),
                          ),
                        ],
                      ),
                      if (excerpt.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          excerpt,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.update, size: 13, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            tanggal == null
                                ? '-'
                                : 'Terakhir diperbarui: ${DateFormat('dd MMM yyyy, HH:mm').format(tanggal)}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text("Tambah Artikel"),
        onPressed: () => _bukaEditor(
          id: null,
          data: const <String, dynamic>{},
        ),
      ),
    );
  }
}


