import 'rincian_tray.dart';

// ============================================================================
// MODEL RIWAYAT: DATA BATCH
// ============================================================================
class DataBatch {
  final String userId;
  final String mitra;
  final String batchKode;
  final String tglBungkus;
  final DateTime tglObj;
  final double totalBerat;
  final int jumlahTray;
  final String status;
  final List<RincianTray> detailTrays;

  const DataBatch({
    required this.userId,
    required this.mitra,
    required this.batchKode,
    required this.tglBungkus,
    required this.tglObj,
    required this.totalBerat,
    required this.jumlahTray,
    required this.status,
    required this.detailTrays,
  });
}
