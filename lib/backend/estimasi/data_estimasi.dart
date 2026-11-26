// ============================================================================
// MODEL ESTIMASI: DATA ESTIMASI
// ============================================================================
class DataEstimasi {
  final String nama;
  final String tray;
  final double telur;
  final String tglMulaiStr;
  final DateTime tglObj;
  final int dateKey;
  final String tglEstimasiStr;
  final double estimasiKg;
  final String searchableText;

  DataEstimasi({
    required this.nama,
    required this.tray,
    required this.telur,
    required this.tglMulaiStr,
    required this.tglObj,
    required this.dateKey,
    required this.tglEstimasiStr,
    required this.estimasiKg,
  }) : searchableText = '${nama.toLowerCase()} ${tray.toLowerCase()}';

  Map<String, dynamic> toExportMap() {
    return {
      'nama': nama,
      'tray': tray,
      'telur': telur,
      'tglMulai': tglMulaiStr,
      'tglEstimasi': tglEstimasiStr,
      'estimasi': estimasiKg,
    };
  }
}
