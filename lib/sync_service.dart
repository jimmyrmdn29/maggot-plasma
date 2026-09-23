// sync_service.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  static const String boxName = 'offline_box';
  static const String antreanKey = 'antrean_input';

  bool _isSyncing = false;

  // Notifier reaktif untuk widget UI (misal: Badge indikator offline)
  final ValueNotifier<int> pendingCountNotifier = ValueNotifier<int>(0);

  // =========================================================================
  // INISIALISASI & AKSES BOX AMAN (ANTI CRASH 'BOX NOT FOUND')
  // =========================================================================
  Future<Box> _getBox() async {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box(boxName);
    }
    return await Hive.openBox(boxName);
  }

  // Mendapatkan jumlah data yang belum terupload untuk ditampilkan di UI
  int get pendingCount {
    if (!Hive.isBoxOpen(boxName)) return 0;
    final box = Hive.box(boxName);
    final List antrean = box.get(antreanKey, defaultValue: []);
    return antrean.length;
  }

  void _updatePendingCount(int count) {
    if (pendingCountNotifier.value != count) {
      pendingCountNotifier.value = count;
    }
  }

  // =========================================================================
  // HELPER SINKRONISASI JARINGAN & SANITASI TIPE DATA
  // =========================================================================
  Future<bool> _cekAdaInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // Membersihkan Map agar aman disimpan ke Hive (konversi Timestamp ke String ISO)
  Map<String, dynamic> _sanitasiUntukHive(Map<String, dynamic> map) {
    final Map<String, dynamic> copy = {};
    map.forEach((key, value) {
      if (value is Timestamp) {
        copy[key] = value.toDate().toIso8601String();
      } else if (value is DateTime) {
        copy[key] = value.toIso8601String();
      } else if (value is Map) {
        copy[key] = _sanitasiUntukHive(Map<String, dynamic>.from(value));
      } else if (value is List) {
        copy[key] = value.map((e) {
          if (e is Map) return _sanitasiUntukHive(Map<String, dynamic>.from(e));
          if (e is Timestamp) return e.toDate().toIso8601String();
          if (e is DateTime) return e.toIso8601String();
          return e;
        }).toList();
      } else {
        copy[key] = value;
      }
    });
    return copy;
  }

  // Memulihkan String ISO kembali menjadi Timestamp Firestore yang sah
  Map<String, dynamic> _pulihkanUntukFirestore(Map<String, dynamic> map) {
    final Map<String, dynamic> copy = {};
    map.forEach((key, value) {
      if (value is String && _apakahIsoDateString(value)) {
        try {
          copy[key] = Timestamp.fromDate(DateTime.parse(value));
        } catch (_) {
          copy[key] = value;
        }
      } else if (value is Map) {
        copy[key] = _pulihkanUntukFirestore(Map<String, dynamic>.from(value));
      } else if (value is List) {
        copy[key] = value.map((e) {
          if (e is Map) return _pulihkanUntukFirestore(Map<String, dynamic>.from(e));
          if (e is String && _apakahIsoDateString(e)) {
            try {
              return Timestamp.fromDate(DateTime.parse(e));
            } catch (_) {
              return e;
            }
          }
          return e;
        }).toList();
      } else {
        copy[key] = value;
      }
    });
    return copy;
  }

  bool _apakahIsoDateString(String str) {
    if (str.length < 10) return false;
    // Deteksi sederhana pola ISO-8601 (misal 2026-09-23T...)
    return RegExp(r'^\d{4}-\d{2}-\d{2}T').hasMatch(str);
  }

  // =========================================================================
  // 1. SIMPAN DATA KE LOKAL (GAK BUTUH INTERNET)
  // =========================================================================
  Future<void> simpanOffline({
    required String tipe,
    required Map<String, dynamic> data,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final String currentUid = user?.uid ?? 'UNKNOWN_UID';

    final box = await _getBox();
    final List antrean = List.from(box.get(antreanKey, defaultValue: []));

    // Sanitasi data sebelum masuk Hive agar tidak crash pada tipe Timestamp
    final Map<String, dynamic> dataBersih = _sanitasiUntukHive(data);

    antrean.add({
      'tipe': tipe,
      'userId': currentUid, // KUNCI KEAMANAN: Cegah kebocoran ke akun lain
      'data': dataBersih,
      'id_lokal': DateTime.now().millisecondsSinceEpoch.toString(), // ID unik lokal
      'dibuatPada': DateTime.now().toIso8601String(),
    });

    await box.put(antreanKey, antrean);
    _updatePendingCount(antrean.length);

    debugPrint("Data offline disimpan. Total antrean: ${antrean.length}");

    // Coba upload langsung (kalau ada sinyal langsung kekirim, kalau offline ya antre)
    unawaited(mulaiProsesSync());
  }

  // =========================================================================
  // 2. PROSES PENGIRIMAN DATA KE FIREBASE
  // =========================================================================
  Future<void> mulaiProsesSync() async {
    if (_isSyncing) return; // Jangan double sync

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final box = await _getBox();
    final List antrean = List.from(box.get(antreanKey, defaultValue: []));
    if (antrean.isEmpty) {
      _updatePendingCount(0);
      return;
    }

    // Cek koneksi internet sebelum eksekusi ke Firestore
    final bool online = await _cekAdaInternet();
    if (!online) {
      debugPrint("Sync ditunda: Perangkat dalam status offline.");
      return;
    }

    _isSyncing = true;
    debugPrint("Memulai sinkronisasi data offline ke Firestore...");

    final List antreanSisa = List.from(antrean);

    for (var rawItem in antrean) {
      final Map<String, dynamic> item = Map<String, dynamic>.from(rawItem as Map);
      final String itemUserId = item['userId']?.toString() ?? '';

      // JIKA DATA MILIK USER LAIN (MISAL GANTI AKUN), LEWATI DULU
      if (itemUserId.isNotEmpty && itemUserId != user.uid) {
        continue;
      }

      try {
        final String tipe = item['tipe'];
        final Map<String, dynamic> dataLokal = Map<String, dynamic>.from(item['data']);

        // Pulihkan tipe data Timestamp resmi Firestore sebelum arrayUnion
        final Map<String, dynamic> dataFirestore = _pulihkanUntukFirestore(dataLokal);

        final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

        if (tipe == 'siklus') {
          await docRef.update({
            'siklus': FieldValue.arrayUnion([dataFirestore]),
            'counterTray': FieldValue.increment(1),
          }).timeout(const Duration(seconds: 10));
        } else if (tipe == 'panen') {
          // Logika untuk menu 2 & 3
          await docRef.update({
            'panen': FieldValue.arrayUnion([dataFirestore]),
          }).timeout(const Duration(seconds: 10));
        } else if (tipe == 'batch') {
          await docRef.update({
            'batch': FieldValue.arrayUnion([dataFirestore]),
          }).timeout(const Duration(seconds: 10));
        }

        // Jika sukses sampai sini, hapus item ini dari antrean sisa
        antreanSisa.removeWhere((e) => e['id_lokal'] == item['id_lokal']);
        debugPrint("Data offline ${item['id_lokal']} sukses terupload ke Firestore.");
      } catch (e) {
        debugPrint("Gagal Sync item ${item['id_lokal']}: $e. Berhenti sementara.");
        break; // Berhenti jika gagal/koneksi putus di tengah jalan
      }
    }

    await box.put(antreanKey, antreanSisa);
    _updatePendingCount(antreanSisa.length);
    _isSyncing = false;
  }

  // =========================================================================
  // 3. FUNGSI UTILITAS TAMBAHAN
  // =========================================================================
  Future<void> bersihkanAntreanUserAktif() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final box = await _getBox();
    final List antrean = List.from(box.get(antreanKey, defaultValue: []));
    antrean.removeWhere((e) => e['userId'] == user.uid);
    await box.put(antreanKey, antrean);
    _updatePendingCount(antrean.length);
  }
}