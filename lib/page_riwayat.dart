// page_riwayat.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

// ============================================================================
// 1. DESIGN THEME CONSTANTS
// ============================================================================
class _RiwayatTheme {
  static const Color primary = Color(0xFF455A64);
  static const Color primaryDark = Color(0xFF1A237E);
  static const Color accentBlue = Color(0xFF1565C0);
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFE65100);
  static const Color textMuted = Color(0xFF546E7A);
  static const Color background = Color(0xFFF9FAFB);
  static const Color surfaceGrey = Color(0xFFECEFF1);
  static const Color tableHeaderBg = Color(0xFFF5F5F5);
  static const Color borderGrey = Color(0xFFE0E0E0);
  static const Color failureBg = Color(0xFFFFEBEE);
  static const Color cardBg = Color(0xFFFAFAFA);
}

// ============================================================================
// 2. TYPE-SAFE DATA MODELS
// ============================================================================
class TrayDetailItem {
  final String nama;
  final String beratTelur;
  final String tglMulaiFormatted;
  final String tanggalPanen;
  final double hasilKg;
  final String status;
  final String gps;
  final String fotoUrl;
  final String fotoBase64;

  const TrayDetailItem({
    required this.nama,
    required this.beratTelur,
    required this.tglMulaiFormatted,
    required this.tanggalPanen,
    required this.hasilKg,
    required this.status,
    required this.gps,
    required this.fotoUrl,
    required this.fotoBase64,
  });

  bool get isGagal => status.toUpperCase() == 'GAGAL';

  factory TrayDetailItem.fromMap(Map<String, dynamic> map) {
    return TrayDetailItem(
      nama: map['nama']?.toString() ?? 'Tray',
      beratTelur: map['beratTelur']?.toString() ?? '0',
      tglMulaiFormatted: map['tglMulaiFormatted']?.toString() ?? '-',
      tanggalPanen: map['tanggalPanen']?.toString() ?? '-',
      hasilKg: double.tryParse(map['hasilKg']?.toString() ?? '0') ?? 0.0,
      status: (map['status']?.toString() ?? 'BERHASIL').toUpperCase(),
      gps: map['gps']?.toString() ?? '-',
      fotoUrl: map['fotoUrl']?.toString() ?? '',
      fotoBase64: map['fotoBase64']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nama': nama,
      'beratTelur': beratTelur,
      'tglMulaiFormatted': tglMulaiFormatted,
      'tanggalPanen': tanggalPanen,
      'hasilKg': hasilKg,
      'status': status,
      'gps': gps,
      'fotoUrl': fotoUrl,
      'fotoBase64': fotoBase64,
    };
  }
}

class BatchItem {
  final String userId;
  final String mitra;
  final String batchKode;
  final String tglBungkus;
  final DateTime tglObj;
  final double totalBerat;
  final int jumlahTray;
  final String status;
  final List<TrayDetailItem> detailTrays;

  const BatchItem({
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

// ============================================================================
// 3. UTILITIES & PARSER
// ============================================================================
class RiwayatUtils {
  static final RegExp _delimiterRegex = RegExp(r'[-/ :T]');

  static DateTime parseDateSuperFast(dynamic value) {
    if (value == null) return DateTime(1970);
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    final String str = value.toString().trim();
    if (str.isEmpty || str == "-") return DateTime(1970);

    final parts = str.split(_delimiterRegex).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 3) {
      final p0 = int.tryParse(parts[0]) ?? 0;
      final p1 = int.tryParse(parts[1]) ?? 0;
      final p2 = int.tryParse(parts[2]) ?? 0;
      final hour = parts.length > 3 ? (int.tryParse(parts[3]) ?? 0) : 0;
      final minute = parts.length > 4 ? (int.tryParse(parts[4]) ?? 0) : 0;
      final second = parts.length > 5 ? (int.tryParse(parts[5]) ?? 0) : 0;

      if (p0 > 1000) return DateTime(p0, p1, p2, hour, minute, second);
      if (p2 > 1000) return DateTime(p2, p1, p0, hour, minute, second);
    }
    return DateTime.tryParse(str) ?? DateTime(1970);
  }

  static Uint8List? safeDecodeBase64(String? base64Str) {
    if (base64Str == null || base64Str.trim().isEmpty) return null;
    try {
      String cleanStr = base64Str.trim();
      if (cleanStr.contains(',')) cleanStr = cleanStr.split(',').last;
      cleanStr = cleanStr.replaceAll('\n', '').replaceAll('\r', '').replaceAll(' ', '');
      return base64Decode(base64.normalize(cleanStr));
    } catch (_) {
      return null;
    }
  }

  static List<BatchItem> parseFirestoreDocs(List<QueryDocumentSnapshot> docs) {
    final List<BatchItem> list = [];

    for (final doc in docs) {
      try {
        final user = doc.data() as Map<String, dynamic>? ?? {};
        if (user['role'] == 'admin') continue;

        final String uidMitra = doc.id;
        final String namaMitra = user['nama']?.toString() ?? "Mitra";
        final dynamic batchRaw = user['batch'];
        if (batchRaw is! List) continue;

        for (final b in batchRaw) {
          if (b is! Map<String, dynamic>) continue;

          final bool isBatchBaru = b.containsKey('batchKode') || b.containsKey('detailTrays');

          if (isBatchBaru) {
            final tglBungkusStr = b['tanggalFormatted']?.toString() ?? "-";
            final tglObj = parseDateSuperFast(b['tanggalBungkus'] ?? tglBungkusStr);

            List<TrayDetailItem> trays = [];
            if (b['detailTrays'] is List) {
              trays = (b['detailTrays'] as List)
                  .whereType<Map<String, dynamic>>()
                  .map((m) => TrayDetailItem.fromMap(m))
                  .toList();
            }

            list.add(
              BatchItem(
                userId: uidMitra,
                mitra: namaMitra,
                batchKode: b['batchKode']?.toString() ?? "BATCH",
                tglBungkus: tglBungkusStr,
                tglObj: tglObj,
                totalBerat: double.tryParse(b['totalBeratKg']?.toString() ?? '0') ?? 0.0,
                jumlahTray: b['jumlahTray'] ?? (b['daftarNamaTray'] as List?)?.length ?? 1,
                status: (b['status']?.toString() ?? "TERBUNGKUS").toUpperCase(),
                detailTrays: trays,
              ),
            );
          } else {
            final tglPanenStr = b['tanggalPanen']?.toString() ?? "-";
            final tglObj = parseDateSuperFast(tglPanenStr);

            list.add(
              BatchItem(
                userId: uidMitra,
                mitra: namaMitra,
                batchKode: "LEGACY-${b['nama'] ?? 'TRAY'}",
                tglBungkus: tglPanenStr,
                tglObj: tglObj,
                totalBerat: double.tryParse(b['hasilKg']?.toString() ?? '0') ?? 0.0,
                jumlahTray: 1,
                status: (b['status']?.toString() ?? "SELESAI").toUpperCase(),
                detailTrays: [TrayDetailItem.fromMap(b)],
              ),
            );
          }
        }
      } catch (e) {
        debugPrint("Error parse doc ${doc.id}: $e");
      }
    }

    return list;
  }
}

// ============================================================================
// 4. EXCEL GENERATION SERVICE
// ============================================================================
class RiwayatExcelEngine {
  static Uint8List? generateExcelBytes(Map<String, dynamic> params) {
    final Map<String, dynamic> batch = params['batch'];
    final List<dynamic> detailTrays = params['detailTrays'];

    var excel = excel_pkg.Excel.createExcel();
    var sheet = excel['Sheet1'];

    final String kodeBatch = batch['batchKode'] ?? 'BATCH';
    final String namaMitra = batch['mitra'] ?? '-';
    final String tglBatch = batch['tglBungkus'] ?? '-';

    sheet.appendRow([excel_pkg.TextCellValue("LAPORAN PANEN BATCH")]);
    sheet.appendRow([excel_pkg.TextCellValue("KODE BATCH:"), excel_pkg.TextCellValue(kodeBatch)]);
    sheet.appendRow([excel_pkg.TextCellValue("NAMA MITRA:"), excel_pkg.TextCellValue(namaMitra)]);
    sheet.appendRow([excel_pkg.TextCellValue("TANGGAL BATCH:"), excel_pkg.TextCellValue(tglBatch)]);
    sheet.appendRow([excel_pkg.TextCellValue("TOTAL HASIL:"), excel_pkg.TextCellValue("${batch['totalBerat']} Kg")]);
    sheet.appendRow([excel_pkg.TextCellValue("STATUS BATCH:"), excel_pkg.TextCellValue(batch['status'] ?? "TERBUNGKUS")]);
    sheet.appendRow([excel_pkg.TextCellValue("")]);

    sheet.appendRow([
      excel_pkg.TextCellValue("NO"),
      excel_pkg.TextCellValue("NAMA TRAY"),
      excel_pkg.TextCellValue("TELUR (G)"),
      excel_pkg.TextCellValue("TGL MULAI"),
      excel_pkg.TextCellValue("TGL PANEN"),
      excel_pkg.TextCellValue("HASIL REAL (KG)"),
      excel_pkg.TextCellValue("STATUS TRAY"),
      excel_pkg.TextCellValue("TITIK KOORDINAT GPS (LINK MAPS)"),
      excel_pkg.TextCellValue("BUKTI FOTO"),
    ]);

    int no = 1;
    double totalKg = 0;

    if (detailTrays.isEmpty) {
      double hasil = double.tryParse(batch['totalBerat'].toString()) ?? 0;
      totalKg += hasil;
      sheet.appendRow([
        excel_pkg.IntCellValue(no++),
        excel_pkg.TextCellValue("Tray Terbungkus (Data Lama)"),
        excel_pkg.TextCellValue("-"),
        excel_pkg.TextCellValue("-"),
        excel_pkg.TextCellValue(tglBatch),
        excel_pkg.DoubleCellValue(hasil),
        excel_pkg.TextCellValue(batch['status'].toString()),
        excel_pkg.TextCellValue("-"),
        excel_pkg.TextCellValue("-"),
      ]);
    } else {
      for (var tray in detailTrays) {
        double hasil = double.tryParse(tray['hasilKg']?.toString() ?? '0') ?? 0;
        totalKg += hasil;

        final String gps = tray['gps']?.toString() ?? '';
        final String fotoUrl = tray['fotoUrl']?.toString() ?? '';
        final bool hasBase64 = tray['fotoBase64'] != null && tray['fotoBase64'].toString().trim().isNotEmpty;

        excel_pkg.CellValue cellGps;
        if (gps.isNotEmpty && gps.contains(',')) {
          final String safeGps = gps.replaceAll('"', '');
          final String mapsLink = "https://maps.google.com/?q=$safeGps";
          cellGps = excel_pkg.FormulaCellValue('=HYPERLINK("$mapsLink", "$safeGps")');
        } else {
          cellGps = excel_pkg.TextCellValue(gps.isEmpty ? "-" : gps);
        }

        excel_pkg.CellValue cellFoto;
        if (fotoUrl.startsWith('http')) {
          final String safeUrl = fotoUrl.replaceAll('"', '%22');
          cellFoto = excel_pkg.FormulaCellValue('=HYPERLINK("$safeUrl", "KLIK UNDUH FOTO")');
        } else if (hasBase64) {
          cellFoto = excel_pkg.TextCellValue("FOTO TERVERIFIKASI (DI APLIKASI)");
        } else {
          cellFoto = excel_pkg.TextCellValue("TIDAK ADA FOTO");
        }

        sheet.appendRow([
          excel_pkg.IntCellValue(no++),
          excel_pkg.TextCellValue(tray['nama']?.toString() ?? '-'),
          excel_pkg.TextCellValue("${tray['beratTelur'] ?? '0'} g"),
          excel_pkg.TextCellValue(tray['tglMulaiFormatted']?.toString() ?? '-'),
          excel_pkg.TextCellValue(tray['tanggalPanen']?.toString() ?? '-'),
          excel_pkg.DoubleCellValue(hasil),
          excel_pkg.TextCellValue((tray['status']?.toString() ?? 'BERHASIL').toUpperCase()),
          cellGps,
          cellFoto,
        ]);
      }
    }

    sheet.appendRow([
      excel_pkg.TextCellValue("TOTAL"),
      excel_pkg.TextCellValue(""),
      excel_pkg.TextCellValue(""),
      excel_pkg.TextCellValue(""),
      excel_pkg.TextCellValue(""),
      excel_pkg.DoubleCellValue(totalKg),
      excel_pkg.TextCellValue(""),
      excel_pkg.TextCellValue(""),
      excel_pkg.TextCellValue(""),
    ]);

    final bytes = excel.encode();
    return bytes != null ? Uint8List.fromList(bytes) : null;
  }
}

// ============================================================================
// 5. WIDGET UTAMA (PLUG & PLAY)
// ============================================================================
class PageRiwayat extends StatefulWidget {
  const PageRiwayat({super.key});

  @override
  State<PageRiwayat> createState() => _PageRiwayatState();
}

class _PageRiwayatState extends State<PageRiwayat> {
  final TextEditingController _searchController = TextEditingController();
  late final Stream<QuerySnapshot> _usersStream;

  String cariMitra = "";
  DateTimeRange? selectedRange;
  bool sortTerbaru = true;

  final Set<String> _downloadingBatches = {};

  int _lastDocHash = 0;
  List<BatchItem> _cachedMasterList = [];

  int _halamanAktif = 1;
  int _barisPerHalaman = 10;
  final List<int> _opsiBaris = [10, 25, 50];

  @override
  void initState() {
    super.initState();
    // Menggunakan stream eksisting Anda, tanpa perlu ubah database!
    _usersStream = FirebaseFirestore.instance.collection('users').snapshots();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _terapkanRentangBaru(DateTimeRange range) {
    setState(() {
      selectedRange = range;
      _halamanAktif = 1;
    });
  }

  Future<List<TrayDetailItem>> _ambilDetailTrays(BatchItem batch) async {
    if (batch.detailTrays.isNotEmpty) {
      return batch.detailTrays;
    }

    // Cek jika tersimpan di sub-koleksi
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(batch.userId)
          .collection('batches')
          .doc(batch.batchKode)
          .get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final dynamic rawList = docSnapshot.data()!['detailTrays'];
        if (rawList is List) {
          return rawList
              .whereType<Map<String, dynamic>>()
              .map((m) => TrayDetailItem.fromMap(m))
              .toList();
        }
      }
    } catch (_) {}

    return [];
  }

  Future<void> _exportSingleBatchToExcel(BatchItem batch) async {
    final String kodeBatch = batch.batchKode;
    if (_downloadingBatches.contains(kodeBatch)) return;

    setState(() {
      _downloadingBatches.add(kodeBatch);
    });

    try {
      final List<TrayDetailItem> detailTrays = await _ambilDetailTrays(batch);

      final Map<String, dynamic> params = {
        'batch': {
          'batchKode': batch.batchKode,
          'mitra': batch.mitra,
          'tglBungkus': batch.tglBungkus,
          'totalBerat': batch.totalBerat,
          'status': batch.status,
        },
        'detailTrays': detailTrays.map((t) => t.toMap()).toList(),
      };

      Uint8List? fileBytes;

      if (kIsWeb) {
        await Future.delayed(const Duration(milliseconds: 40));
        fileBytes = RiwayatExcelEngine.generateExcelBytes(params);
      } else {
        fileBytes = await compute(RiwayatExcelEngine.generateExcelBytes, params);
      }

      if (fileBytes == null) throw Exception("Format Excel gagal dibuat.");

      final String namaFileExcel = "Batch_${batch.batchKode.replaceAll(RegExp(r'[^\w\s]+'), '_')}.xlsx";

      if (kIsWeb) {
        final excel = excel_pkg.Excel.decodeBytes(fileBytes);
        excel.save(fileName: namaFileExcel);
      } else {
        final Directory appDir = await getApplicationDocumentsDirectory();
        final String pathExcel = '${appDir.path}/$namaFileExcel';
        final File file = File(pathExcel);
        await file.writeAsBytes(fileBytes, flush: true);
        await OpenFilex.open(pathExcel);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Berhasil mengunduh $namaFileExcel"),
            backgroundColor: _RiwayatTheme.success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal unduh: $e"),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloadingBatches.remove(kodeBatch);
        });
      }
    }
  }

  // ==========================================================================
  // 6. DIALOG FILTER TANGGAL
  // ==========================================================================
  Future<void> _bukaFilterTanggalCepat(BuildContext context) async {
    final now = DateTime.now();
    DateTime tempStart = selectedRange?.start ?? now.subtract(const Duration(days: 7));
    DateTime tempEnd = selectedRange?.end ?? now;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 4,
              child: Container(
                width: 420,
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Pilih Rentang Tanggal",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        )
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text("PILIHAN CEPAT", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 8),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildPresetChip("Hari Ini", () {
                          final today = DateTime(now.year, now.month, now.day);
                          _terapkanRentangBaru(DateTimeRange(start: today, end: today));
                          Navigator.pop(ctx);
                        }),
                        _buildPresetChip("7 Hari Terakhir", () {
                          final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
                          final end = DateTime(now.year, now.month, now.day);
                          _terapkanRentangBaru(DateTimeRange(start: start, end: end));
                          Navigator.pop(ctx);
                        }),
                        _buildPresetChip("Bulan Ini", () {
                          final start = DateTime(now.year, now.month, 1);
                          final end = DateTime(now.year, now.month + 1, 0);
                          _terapkanRentangBaru(DateTimeRange(start: start, end: end));
                          Navigator.pop(ctx);
                        }),
                        _buildPresetChip("Bulan Lalu", () {
                          final start = DateTime(now.year, now.month - 1, 1);
                          final end = DateTime(now.year, now.month, 0);
                          _terapkanRentangBaru(DateTimeRange(start: start, end: end));
                          Navigator.pop(ctx);
                        }),
                      ],
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Divider(height: 1),
                    ),

                    const Text("RENTANG KUSTOM", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: tempStart,
                                firstDate: DateTime(now.year - 3),
                                lastDate: DateTime(now.year + 1),
                              );
                              if (picked != null) {
                                setModalState(() {
                                  tempStart = picked;
                                  if (tempEnd.isBefore(tempStart)) {
                                    tempEnd = tempStart;
                                  }
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Dari", style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  const SizedBox(height: 2),
                                  Text(
                                    DateFormat('dd MMM yyyy').format(tempStart),
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: tempEnd.isBefore(tempStart) ? tempStart : tempEnd,
                                firstDate: tempStart,
                                lastDate: DateTime(now.year + 1),
                              );
                              if (picked != null) {
                                setModalState(() {
                                  tempEnd = picked;
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Sampai", style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  const SizedBox(height: 2),
                                  Text(
                                    DateFormat('dd MMM yyyy').format(tempEnd),
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _RiwayatTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          _terapkanRentangBaru(DateTimeRange(start: tempStart, end: tempEnd));
                          Navigator.pop(ctx);
                        },
                        child: const Text("TERAPKAN TANGGAL", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPresetChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF37474F))),
      backgroundColor: _RiwayatTheme.surfaceGrey,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      onPressed: onTap,
    );
  }

  // ==========================================================================
  // 7. DIALOG DETAIL TRAY & BUKTI FOTO
  // ==========================================================================
  void _tampilkanDetailTrayDialog(BatchItem batch) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final List<TrayDetailItem> detail = await _ambilDetailTrays(batch);

    if (!mounted) return;
    Navigator.pop(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(batch.batchKode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text("Mitra: ${batch.mitra} | ${batch.tglBungkus}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        content: SizedBox(
          width: 550,
          child: detail.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Center(child: Text("Tidak ada rincian tray tersimpan di database.")),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: detail.length,
                  itemBuilder: (context, i) {
                    final t = detail[i];
                    final Uint8List? fotoBytes = RiwayatUtils.safeDecodeBase64(t.fotoBase64);
                    final bool hasImage = t.fotoUrl.isNotEmpty || fotoBytes != null;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      color: t.isGagal ? _RiwayatTheme.failureBg : _RiwayatTheme.cardBg,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            InkWell(
                              onTap: hasImage
                                  ? () => _tampilkanFotoBesar(
                                        context,
                                        bytes: fotoBytes,
                                        url: t.fotoUrl,
                                        namaTray: t.nama,
                                        gps: t.gps,
                                      )
                                  : null,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: fotoBytes != null
                                    ? Image.memory(
                                        fotoBytes,
                                        width: 65,
                                        height: 65,
                                        cacheWidth: 140,
                                        cacheHeight: 140,
                                        fit: BoxFit.cover,
                                        filterQuality: FilterQuality.medium,
                                      )
                                    : (t.fotoUrl.isNotEmpty
                                        ? Image.network(
                                            t.fotoUrl,
                                            width: 65,
                                            height: 65,
                                            cacheWidth: 140,
                                            cacheHeight: 140,
                                            fit: BoxFit.cover,
                                            filterQuality: FilterQuality.medium,
                                          )
                                        : Container(
                                            width: 65,
                                            height: 65,
                                            color: _RiwayatTheme.borderGrey,
                                            child: const Icon(Icons.no_photography, size: 24, color: Colors.grey),
                                          )),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(t.nama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  const SizedBox(height: 2),
                                  Text(
                                    t.isGagal ? "Status: MATI / GAGAL" : "Hasil: ${t.hasilKg} Kg (Telur: ${t.beratTelur} g)",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: t.isGagal ? Colors.red[800] : Colors.green[800],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text("📍 GPS: ${t.gps}", style: const TextStyle(fontSize: 11, color: Colors.black87)),
                                  Text(
                                    "🗓️ Mulai: ${t.tglMulaiFormatted} | Panen: ${t.tanggalPanen}",
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("TUTUP")),
        ],
      ),
    );
  }

  void _tampilkanFotoBesar(
    BuildContext context, {
    Uint8List? bytes,
    String? url,
    required String namaTray,
    required String gps,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 650),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text("Bukti Panen: $namaTray", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: InteractiveViewer(
                    panEnabled: true,
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: bytes != null
                        ? Image.memory(bytes, fit: BoxFit.contain, filterQuality: FilterQuality.medium)
                        : (url != null && url.isNotEmpty
                            ? Image.network(url, fit: BoxFit.contain, filterQuality: FilterQuality.medium)
                            : const Center(child: Icon(Icons.no_photography, size: 50, color: Colors.grey))),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: _RiwayatTheme.tableHeaderBg, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text("Koordinat GPS: $gps", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // 8. BUILD TABLE & UI
  // ==========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _RiwayatTheme.background,
      body: StreamBuilder<QuerySnapshot>(
        stream: _usersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _cachedMasterList.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Terjadi kesalahan: ${snapshot.error}"));
          }

          // Caching hash-based agar tidak re-parse jika data Firestore tidak berubah
          if (snapshot.hasData) {
            final docs = snapshot.data!.docs;
            final int currentHash = Object.hashAll(docs.map((d) => d.id));
            if (_lastDocHash != currentHash) {
              _lastDocHash = currentHash;
              _cachedMasterList = RiwayatUtils.parseFirestoreDocs(docs);
            }
          }

          final query = cariMitra.toLowerCase().trim();

          final filtered = _cachedMasterList.where((item) {
            final bool matchNama = query.isEmpty ||
                item.mitra.toLowerCase().contains(query) ||
                item.batchKode.toLowerCase().contains(query);

            bool matchTgl = true;
            if (selectedRange != null) {
              final DateTime d = item.tglObj;
              final DateTime itemDate = DateTime(d.year, d.month, d.day);
              final DateTime start = DateTime(selectedRange!.start.year, selectedRange!.start.month, selectedRange!.start.day);
              final DateTime end = DateTime(selectedRange!.end.year, selectedRange!.end.month, selectedRange!.end.day);

              matchTgl = !itemDate.isBefore(start) && !itemDate.isAfter(end);
            }

            return matchNama && matchTgl;
          }).toList();

          filtered.sort((a, b) {
            return sortTerbaru ? b.tglObj.compareTo(a.tglObj) : a.tglObj.compareTo(b.tglObj);
          });

          final int totalData = filtered.length;
          final int totalHalaman = totalData == 0 ? 1 : (totalData / _barisPerHalaman).ceil();

          if (_halamanAktif > totalHalaman) _halamanAktif = totalHalaman;
          if (_halamanAktif < 1) _halamanAktif = 1;

          final int startIndex = (totalData == 0) ? 0 : (_halamanAktif - 1) * _barisPerHalaman;
          final int endIndex = min(startIndex + _barisPerHalaman, totalData);
          final List<BatchItem> dataHalamanIni =
              (totalData == 0) ? [] : filtered.sublist(startIndex, endIndex);

          return Column(
            children: [
              _buildTopToolbar(context),
              const Divider(height: 1, thickness: 1),
              Expanded(child: _buildDataTable(dataHalamanIni)),
              const Divider(height: 1, thickness: 1),
              _buildPaginationBar(totalData, totalHalaman, startIndex, endIndex),
              const Divider(height: 1, thickness: 1),
              _buildFooter(filtered),
            ],
          );
        },
      ),
    );
  }

  // ==========================================================================
  // 9. SUB-WIDGETS
  // ==========================================================================
  Widget _buildTopToolbar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (v) {
                setState(() {
                  cariMitra = v;
                  _halamanAktif = 1;
                });
              },
              decoration: InputDecoration(
                hintText: "Cari nama mitra / kode batch...",
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(width: 12),

          Container(
            height: 44,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: _RiwayatTheme.surfaceGrey,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSortTab(
                  label: "Terbaru",
                  isActive: sortTerbaru,
                  activeColor: _RiwayatTheme.accentBlue,
                  onTap: () {
                    if (sortTerbaru) return;
                    setState(() {
                      sortTerbaru = true;
                      _halamanAktif = 1;
                    });
                  },
                ),
                _buildSortTab(
                  label: "Terlama",
                  isActive: !sortTerbaru,
                  activeColor: _RiwayatTheme.warning,
                  onTap: () {
                    if (!sortTerbaru) return;
                    setState(() {
                      sortTerbaru = false;
                      _halamanAktif = 1;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          ElevatedButton.icon(
            onPressed: () => _bukaFilterTanggalCepat(context),
            icon: const Icon(Icons.date_range, size: 16),
            label: Text(
              selectedRange == null
                  ? "FILTER TANGGAL"
                  : "${DateFormat('dd/MM').format(selectedRange!.start)} - ${DateFormat('dd/MM').format(selectedRange!.end)}",
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              backgroundColor: _RiwayatTheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          if (selectedRange != null) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: "Hapus Filter Tanggal",
              onPressed: () {
                setState(() {
                  selectedRange = null;
                  _halamanAktif = 1;
                });
              },
              icon: const Icon(Icons.close, color: Colors.red),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildSortTab({
    required String label,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isActive
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2))]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? activeColor : _RiwayatTheme.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildDataTable(List<BatchItem> dataHalamanIni) {
    if (dataHalamanIni.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 50, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text("Data batch tidak ditemukan", style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(_RiwayatTheme.tableHeaderBg),
                columnSpacing: 22,
                dataRowMinHeight: 52,
                dataRowMaxHeight: 52,
                columns: const [
                  DataColumn(label: Text("NAMA MITRA", style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("KODE BATCH", style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("TGL BUNGKUS", style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("JUMLAH TRAY", style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("TOTAL HASIL", style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("AKSI", style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: dataHalamanIni.map((item) {
                  final bool isDownloading = _downloadingBatches.contains(item.batchKode);

                  return DataRow(
                    cells: [
                      DataCell(Text(item.mitra, style: const TextStyle(fontWeight: FontWeight.w600))),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(item.batchKode, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      DataCell(Text(item.tglBungkus)),
                      DataCell(Text("${item.jumlahTray} Tray", style: const TextStyle(fontWeight: FontWeight.w500))),
                      DataCell(
                        Text(
                          "${item.totalBerat} Kg",
                          style: const TextStyle(fontWeight: FontWeight.bold, color: _RiwayatTheme.accentBlue),
                        ),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_red_eye_outlined, color: Colors.blueGrey),
                              tooltip: "Lihat Detail & Foto",
                              onPressed: () => _tampilkanDetailTrayDialog(item),
                            ),
                            isDownloading
                                ? const Padding(
                                    padding: EdgeInsets.all(12.0),
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2.2, color: _RiwayatTheme.success),
                                    ),
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.file_download_outlined, color: _RiwayatTheme.success),
                                    tooltip: "Unduh Excel Batch Ini",
                                    onPressed: () => _exportSingleBatchToExcel(item),
                                  ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaginationBar(int totalData, int totalHalaman, int startIndex, int endIndex) {
    List<int> nomorHalaman = [];
    int startPage = max(1, _halamanAktif - 2);
    int endPage = min(totalHalaman, startPage + 4);

    if (endPage - startPage < 4) {
      startPage = max(1, endPage - 4);
    }
    if (startPage < 1) startPage = 1;

    for (int i = startPage; i <= endPage; i++) {
      nomorHalaman.add(i);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                totalData == 0
                    ? "Menampilkan 0 data"
                    : "Menampilkan ${startIndex + 1} - $endIndex dari $totalData batch",
                style: const TextStyle(fontSize: 12, color: Color(0xFF616161), fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 16),
              Row(
                children: [
                  const Text("Baris: ", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  DropdownButton<int>(
                    value: _barisPerHalaman,
                    isDense: true,
                    underline: const SizedBox(),
                    items: _opsiBaris.map((val) {
                      return DropdownMenuItem<int>(
                        value: val,
                        child: Text("$val", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _barisPerHalaman = val;
                          _halamanAktif = 1;
                        });
                      }
                    },
                  ),
                ],
              )
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.first_page, size: 20),
                tooltip: "Halaman Pertama",
                onPressed: _halamanAktif > 1 ? () => setState(() => _halamanAktif = 1) : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                tooltip: "Sebelumnya",
                onPressed: _halamanAktif > 1 ? () => setState(() => _halamanAktif--) : null,
              ),
              const SizedBox(width: 4),
              ...nomorHalaman.map((pageNo) {
                final bool isActive = pageNo == _halamanAktif;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(36, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      backgroundColor: isActive ? _RiwayatTheme.primary : Colors.transparent,
                      side: BorderSide(
                        color: isActive ? _RiwayatTheme.primary : _RiwayatTheme.borderGrey,
                        width: 1.0,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () => setState(() => _halamanAktif = pageNo),
                    child: Text(
                      "$pageNo",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        color: isActive ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                tooltip: "Berikutnya",
                onPressed: _halamanAktif < totalHalaman ? () => setState(() => _halamanAktif++) : null,
              ),
              IconButton(
                icon: const Icon(Icons.last_page, size: 20),
                tooltip: "Halaman Terakhir",
                onPressed: _halamanAktif < totalHalaman ? () => setState(() => _halamanAktif = totalHalaman) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(List<BatchItem> data) {
    double totalKg = data.fold(0.0, (acc, item) => acc + item.totalBerat);
    int totalTray = data.fold(0, (acc, item) => acc + item.jumlahTray);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_outlined, color: Colors.blueGrey, size: 20),
              const SizedBox(width: 8),
              Text(
                "Total Record: ${data.length} Batch ($totalTray Tray)",
                style: const TextStyle(fontSize: 13, color: Color(0xFF424242), fontWeight: FontWeight.w500),
              ),
            ],
          ),
          Text(
            "Total Panen: ${totalKg.toStringAsFixed(1)} Kg",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: _RiwayatTheme.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}