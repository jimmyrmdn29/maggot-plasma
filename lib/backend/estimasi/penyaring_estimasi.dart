// ============================================================================
// PENYARING & SORTER DATA ESTIMASI
// ============================================================================
import './data_estimasi.dart';

class PenyaringEstimasi {
  static List<DataEstimasi> terapkanFilter({
    required List<DataEstimasi> data,
    String? cariMitra,
    int? startDateKey,
    int? endDateKey,
  }) {
    var hasil = data;

    final String kunciCari = (cariMitra ?? '').trim().toLowerCase();
    if (kunciCari.isNotEmpty) {
      hasil = hasil.where((item) => item.searchableText.contains(kunciCari)).toList();
    }

    if (startDateKey != null && endDateKey != null) {
      hasil = hasil
          .where((item) => item.dateKey >= startDateKey && item.dateKey <= endDateKey)
          .toList();
    }

    return hasil;
  }

  static List<DataEstimasi> mengurutkan({
    required List<DataEstimasi> data,
    required bool sortTerbaru,
  }) {
    final List<DataEstimasi> hasil = List<DataEstimasi>.from(data);
    hasil.sort((a, b) => sortTerbaru ? b.dateKey.compareTo(a.dateKey) : a.dateKey.compareTo(b.dateKey));
    return hasil;
  }
}
