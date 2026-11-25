import 'package:cloud_firestore/cloud_firestore.dart';

import 'artikel_block.dart';

// =========================================================================
// PARSER / HELPER MURNI ARTIKEL
// =========================================================================
// Tidak ada widget dan tidak ada akses Firestore di file ini.
class ArtikelParser {
  static String? bersihkanUrl(dynamic value) {
    if (value == null) return null;
    final String url = value.toString().trim();
    return url.isEmpty ? null : url;
  }

  static DateTime? toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static List<ArtikelBlock> parseKonten(dynamic raw) {
    if (raw is! List) return const <ArtikelBlock>[];
    return raw
        .whereType<Map>()
        .map((item) => ArtikelBlock.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  // Artikel lama hanya punya field `isi`: jadikan satu blok teks.
  static List<ArtikelBlock> dariIsiLama(dynamic isi) {
    final String text = (isi ?? '').toString().trim();
    if (text.isEmpty) return const <ArtikelBlock>[];
    return <ArtikelBlock>[ArtikelBlock.teks(text)];
  }

  // Prioritas: konten baru -> fallback isi lama.
  static List<ArtikelBlock> kontenDariDoc(Map<String, dynamic> data) {
    final List<ArtikelBlock> parsed = parseKonten(data['konten']);
    if (parsed.isNotEmpty) return parsed;
    return dariIsiLama(data['isi']);
  }

  // Ringkasan untuk excerpt di daftar.
  static String ringkasanIsi(List<ArtikelBlock> konten) {
    return konten
        .where((block) => block.isTeks)
        .map((block) => block.nilai.trim())
        .where((text) => text.isNotEmpty)
        .join('\n\n')
        .trim();
  }
}
