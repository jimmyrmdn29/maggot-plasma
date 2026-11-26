// ============================================================================
// PENYARING PANEN: FILTER TRAY YANG MASIH AKTIF DI MENU 3
// ============================================================================
// Satu tanggung jawab: memilih tray yang benar-benar belum pernah dibungkus.
//
// Sumber kebenaran utama adalah `dbBatch` (ringkasan batch di Firestore),
// bukan blacklist lokal per perangkat.
//
// Fase 4d1: format batch baru (ringkasan) via `daftarNamaTray`.
class PenyaringPanen {
  static List<Map<String, dynamic>> daftarAktif({
    required List<Map<String, dynamic>> daftarPanen,
    required List<Map<String, dynamic>> daftarBatch,
  }) {
    final Set<String> namaSudahDibungkus = <String>{};

    for (final batch in daftarBatch) {
      final dynamic rawNames = batch['daftarNamaTray'];
      if (rawNames is List) {
        for (final name in rawNames) {
          namaSudahDibungkus.add(name.toString());
        }
      }

      final dynamic rawDetailTrays = batch['detailTrays'];
      if (rawDetailTrays is List) {
        for (final detail in rawDetailTrays) {
          if (detail is Map<String, dynamic>) {
            final dynamic rawName = detail['nama'];
            if (rawName != null) {
              namaSudahDibungkus.add(rawName.toString());
            }
          }
        }
      }

      final dynamic rawLegacyName = batch['nama'];
      if (rawLegacyName != null) {
        namaSudahDibungkus.add(rawLegacyName.toString());
      }
    }

    return daftarPanen
        .where((panen) =>
            !namaSudahDibungkus.contains((panen['nama'] ?? '').toString()))
        .toList();
  }
}
