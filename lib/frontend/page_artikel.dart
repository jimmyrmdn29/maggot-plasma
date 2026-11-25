import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../backend/artikel/artikel_repository.dart';
import 'artikel/widget/artikel_card.dart';
import 'page_detail_artikel.dart';

// =========================================================================
// 1. WIDGET UTAMA (MENU ARTIKEL - MITRA)
// =========================================================================
class PageArtikel extends StatefulWidget {
  const PageArtikel({super.key});

  @override
  State<PageArtikel> createState() => _PageArtikelState();
}

class _PageArtikelState extends State<PageArtikel> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = ArtikelRepository.streamArtikel();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ErrorState(message: snapshot.error.toString());
          }

          final docs = snapshot.data?.docs ?? const [];
          if (docs.isEmpty) {
            return const _EmptyArtikelState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              return ArtikelCard(
                artikelId: doc.id,
                data: data,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PageDetailArtikel(
                        artikelId: doc.id,
                        data: data,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// =========================================================================
// 2. STATE KOSONG & ERROR
// =========================================================================
class _EmptyArtikelState extends StatelessWidget {
  const _EmptyArtikelState();

  @override
  Widget build(BuildContext context) {
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
            "Artikel dari admin akan muncul di sini.",
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.red),
            const SizedBox(height: 12),
            const Text(
              "Gagal memuat artikel.",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}


