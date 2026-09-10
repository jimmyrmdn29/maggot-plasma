import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final Box _box = Hive.box('offline_box');
  bool _isSyncing = false;

  // Mendapatkan jumlah data yang belum terupload untuk ditampilkan di UI
  int get pendingCount {
    List antrean = _box.get('antrean_input', defaultValue: []);
    return antrean.length;
  }

  // 1. Simpan Data ke Lokal (Gak butuh internet)
  Future<void> simpanOffline({required String tipe, required Map<String, dynamic> data}) async {
    List antrean = List.from(_box.get('antrean_input', defaultValue: []));
    
    antrean.add({
      'tipe': tipe,
      'data': data,
      'id_lokal': DateTime.now().millisecondsSinceEpoch.toString(), // ID unik lokal
    });

    await _box.put('antrean_input', antrean);
    print("Data berhasil disimpan di lokal. Total antrean: ${antrean.length}");
    
    // Coba upload langsung (kalau ada sinyal langsung kekirim, kalau nggak ya antre)
    mulaiProsesSync();
  }

  // 2. Proses Pengiriman Data ke Firebase
  Future<void> mulaiProsesSync() async {
    if (_isSyncing) return; // Jangan double sync
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    List antrean = List.from(_box.get('antrean_input', defaultValue: []));
    if (antrean.isEmpty) return;

    _isSyncing = true;
    print("Memulai sinkronisasi data...");

    List antreanSisa = List.from(antrean);

    for (var item in antrean) {
      try {
        String tipe = item['tipe'];
        Map<String, dynamic> dataRaw = Map<String, dynamic>.from(item['data']);
        
        // Konversi kembali Timestamp jika ada (Hive menyimpan sebagai String/Map)
        // Jika di menu1 menggunakan Timestamp, kita handle di sini
        if (dataRaw['tanggalMulai'] is String) {
           // Jika tersimpan sebagai string ISO, biarkan atau ubah sesuai kebutuhan Firestore
        }

        final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

        if (tipe == 'siklus') {
          await docRef.update({
            'siklus': FieldValue.arrayUnion([dataRaw]),
            'counterTray': FieldValue.increment(1),
          });
        } else if (tipe == 'panen') {
          // Logika untuk menu 2 & 3
          await docRef.update({
            'panen': FieldValue.arrayUnion([dataRaw]),
            // Jika ada logika hapus siklus, harus dihandle khusus atau dikirim datanya
          });
        } else if (tipe == 'batch') {
          await docRef.update({
            'batch': FieldValue.arrayUnion([dataRaw]),
          });
        }

        // Jika sukses sampai sini, hapus dari antrean
        antreanSisa.removeWhere((e) => e['id_lokal'] == item['id_lokal']);
        print("Data ${item['id_lokal']} sukses terupload.");
        
      } catch (e) {
        print("Gagal Sync: $e. Berhenti sementara (mungkin offline)");
        break; // Berhenti jika gagal (biasanya karena sinyal hilang)
      }
    }

    await _box.put('antrean_input', antreanSisa);
    _isSyncing = false;
  }
}