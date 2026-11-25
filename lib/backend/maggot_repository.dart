import 'package:cloud_firestore/cloud_firestore.dart';

// =========================================================================
// REPOSITORY LAYER (Pusat Transaksi & Operasi Firestore)
// =========================================================================
class MaggotRepository {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Menu 1: Tambah Banyak Tray Sekaligus
  static Future<void> tambahBanyakTray({
    required String uid,
    required String namaMitra,
    required int counterAwal,
    required List<Map<String, dynamic>> daftarTrayBaru,
    required List<Map<String, dynamic>> dbSiklusLama,
  }) async {
    final List<Map<String, dynamic>> hasilBaru = [];

    for (int i = 0; i < daftarTrayBaru.length; i++) {
      final item = daftarTrayBaru[i];
      hasilBaru.add({
        "peternak": namaMitra,
        "nama": "Tray ${counterAwal + i}",
        "beratTelur": item['beratTelur'],
        "tanggalMulai": item['tanggalMulai'],
        "cekM1": null,
        "cekM2": null,
      });
    }

    dbSiklusLama.addAll(hasilBaru);

    await _db.collection('users').doc(uid).update({
      'siklus': dbSiklusLama,
      'counterTray': counterAwal + daftarTrayBaru.length,
    });
  }

  // Menu 2: Verifikasi Sehat M1/M2
  static Future<void> konfirmasiSehat({
    required String uid,
    required List<Map<String, dynamic>> dbSiklus,
    required int index,
    required int minggu,
  }) async {
    dbSiklus[index]['cekM$minggu'] = DateTime.now().toIso8601String();
    await _db.collection('users').doc(uid).update({'siklus': dbSiklus});
  }

  // Menu 2: Pindah dari Siklus ke Panen
  static Future<void> pindahkanKePanen({
    required String uid,
    required List<Map<String, dynamic>> dbSiklus,
    required List<Map<String, dynamic>> dbPanen,
    required int index,
    required Map<String, dynamic> dataBaru,
  }) async {
    dbPanen.add(dataBaru);
    dbSiklus.removeAt(index);
    await _db.collection('users').doc(uid).update({
      'siklus': dbSiklus,
      'panen': dbPanen,
    });
  }

  // Menu 3: Bungkus Batch Atomik (Sub-koleksi + Ringkasan Ringan)
  static Future<void> bungkusBatch({
    required String uid,
    required Map<String, dynamic> paketBatch,
    required List<Map<String, dynamic>> dbPanenLama,
  }) async {
    final List<dynamic> detailTrays = paketBatch['detailTrays'] ?? [];
    final Set<String> namaTraySelesai = detailTrays.map((t) => t['nama'].toString()).toSet();

    final sisaPanen = dbPanenLama.where((item) => !namaTraySelesai.contains(item['nama'].toString())).toList();
    final String batchKode = paketBatch['batchKode'] ?? "BATCH-${DateTime.now().millisecondsSinceEpoch}";

    final batchWrite = _db.batch();

    // 1. Simpan detail penuh ke Sub-koleksi
    final docBatchRef = _db.collection('users').doc(uid).collection('batches').doc(batchKode);
    batchWrite.set(docBatchRef, paketBatch);

    // 2. Buat ringkasan ringan untuk Menu 4 (Anti limit 1MB Firestore)
    final ringkasanMenuEmpat = {
      'batchKode': batchKode,
      'tanggalBungkus': paketBatch['tanggalBungkus'],
      'tanggalFormatted': paketBatch['tanggalFormatted'],
      'totalBeratKg': paketBatch['totalBeratKg'],
      'jumlahTray': paketBatch['jumlahTray'],
      'status': paketBatch['status'],
      'daftarNamaTray': detailTrays.map((e) => e['nama']).toList(),
    };

    // 3. Simpan ke Dokumen Utama
    final docUserRef = _db.collection('users').doc(uid);
    batchWrite.update(docUserRef, {
      'panen': sisaPanen,
      'batch': FieldValue.arrayUnion([ringkasanMenuEmpat]),
    });

    await batchWrite.commit();
  }

  // Menu 3: Update URL Foto Cloudinary ke Sub-koleksi Batches
  static Future<void> updateFotoBatch({
    required String uid,
    required String batchKode,
    required List<dynamic> detailTraysTerbaru,
  }) async {
    await _db.collection('users').doc(uid).collection('batches').doc(batchKode).update({
      'detailTrays': detailTraysTerbaru,
    });
  }

  // Menu 4: Hapus Batch Manual
  static Future<void> hapusBatchManual({
    required String uid,
    required List<Map<String, dynamic>> dbBatch,
    required int index,
  }) async {
    dbBatch.removeAt(index);
    await _db.collection('users').doc(uid).update({'batch': dbBatch});
  }
}
