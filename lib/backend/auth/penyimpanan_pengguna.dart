import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================================================
// PENYIMPANAN PENGGUNA: AKSES DOKUMEN USERS DI FIRESTORE
// ============================================================================
class PenyimpananPengguna {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<DocumentSnapshot> ambilDokumenUser(String uid) {
    return _db.collection('users').doc(uid).get();
  }

  Future<bool> cekRoleAdmin(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    final data = doc.data();
    return data != null && data['role'] == 'admin';
  }

  Future<void> buatDokumenUserBaru(String uid, {required String nama, required String email}) async {
    await _db.collection('users').doc(uid).set({
      'nama': nama.trim(),
      'email': email.trim(),
      'role': 'mitra',
      'counterTray': 1,
      'siklus': [],
      'panen': [],
      'batch': [],
    });
  }

  Future<void> buatDokumenMitra({
    required String uid,
    required String nama,
    required String email,
    required String dibuatOleh,
  }) async {
    await _db.collection('users').doc(uid).set({
      'nama': nama.trim(),
      'email': email.trim(),
      'role': 'mitra',
      'counterTray': 1,
      'siklus': [],
      'panen': [],
      'batch': [],
      'terakhirResetCounter': FieldValue.serverTimestamp(),
      'dibuatOlehAdmin': dibuatOleh,
      'tanggalDibuat': FieldValue.serverTimestamp(),
    });
  }
}
