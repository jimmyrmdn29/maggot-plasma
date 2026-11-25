import 'package:cloud_firestore/cloud_firestore.dart';

// =============================================================================
// MODEL ENTITY TYPE-SAFE (CLEAN ARCHITECTURE)
// =============================================================================
class MitraItem {
  final String uid;
  final String nama;
  final String email;
  final int counterTray;
  final List<dynamic> siklus;

  MitraItem({
    required this.uid,
    required this.nama,
    required this.email,
    required this.counterTray,
    required this.siklus,
  });

  factory MitraItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final rawSiklus = data['siklus'];
    return MitraItem(
      uid: doc.id,
      nama: (data['nama'] ?? "Tanpa Nama").toString().trim(),
      email: (data['email'] ?? "-").toString().trim(),
      counterTray: data['counterTray'] is int
          ? data['counterTray'] as int
          : int.tryParse(data['counterTray']?.toString() ?? "1") ?? 1,
      siklus: rawSiklus is List ? rawSiklus : [],
    );
  }

  String get inisial {
    if (nama.isEmpty || nama == "Tanpa Nama") return "?";
    return nama[0].toUpperCase();
  }
}
