import 'package:cloud_firestore/cloud_firestore.dart';

import 'artikel_block.dart';
import 'artikel_parser.dart';

// =========================================================================
// REPOSITORY LAYER — ARTIKEL
// =========================================================================
// Hanya akses Firestore. Tidak ada widget/UI di file ini.
class ArtikelRepository {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Stream<QuerySnapshot<Map<String, dynamic>>> streamArtikel() {
    return _db
        .collection('artikel')
        .orderBy('dibuatPada', descending: true)
        .snapshots();
  }

  static Future<void> simpanArtikel({
    required String uid,
    required String judul,
    String isi = '',
    List<ArtikelBlock>? konten,
    String? gambarUrl,
    String? id,
  }) async {
    final List<ArtikelBlock> blokFinal = (konten == null || konten.isEmpty)
        ? (isi.trim().isEmpty
            ? const <ArtikelBlock>[]
            : <ArtikelBlock>[ArtikelBlock.teks(isi.trim())])
        : konten;

    final String judulBersih = judul.trim();
    final String ringkasan = ArtikelParser.ringkasanIsi(blokFinal);
    final String? urlBersih = (gambarUrl == null || gambarUrl.trim().isEmpty)
        ? null
        : gambarUrl.trim();

    final Map<String, dynamic> data = <String, dynamic>{
      'judul': judulBersih,
      'isi': ringkasan,
      'konten': blokFinal.map((block) => block.toJson()).toList(),
      'gambarUrl': urlBersih,
      'diupdateOleh': uid,
      'diupdatePada': FieldValue.serverTimestamp(),
    };

    if (id == null) {
      data['dibuatOleh'] = uid;
      data['dibuatPada'] = FieldValue.serverTimestamp();
      await _db.collection('artikel').add(data);
    } else {
      await _db.collection('artikel').doc(id).update(data);
    }
  }

  static Future<void> hapusArtikel(String id) async {
    await _db.collection('artikel').doc(id).delete();
  }
}
