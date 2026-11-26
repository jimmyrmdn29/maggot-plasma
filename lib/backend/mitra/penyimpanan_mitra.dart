import 'package:cloud_firestore/cloud_firestore.dart';

import '../mitra_item.dart';

// ============================================================================
// PENYIMPANAN MITRA: AKSES DATA MITRA DI FIRESTORE
// ============================================================================
class PenyimpananMitra {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot> streamSemuaUser() {
    return _db.collection('users').snapshots();
  }

  Future<void> resetCounterTray(String uid) async {
    await _db.collection('users').doc(uid).set({
      'counterTray': 1,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> hapusMitra(String uid, String nama) async {
    await _db.collection('akun_auth_perlu_dihapus').doc(uid).set({
      'nama': nama,
      'uid': uid,
      'dihapusPada': FieldValue.serverTimestamp(),
    });
    await _db.collection('users').doc(uid).delete();
  }

  static List<MitraItem> parseDaftarMitra(List<QueryDocumentSnapshot> docs) {
    return docs
        .where((d) {
          final data = d.data() as Map<String, dynamic>? ?? {};
          return data['role'] == 'mitra';
        })
        .map((doc) => MitraItem.fromFirestore(doc))
        .toList();
  }

  static MitraItem? parseSatuMitra(String uid, Map<String, dynamic> data) {
    if (data['role'] != 'mitra') return null;
    return MitraItem.fromMap(uid, data);
  }
}
