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

class PageRiwayat extends StatefulWidget {
  const PageRiwayat({super.key});

  @override
  State<PageRiwayat> createState() => _PageRiwayatState();
}

class _PageRiwayatState extends State<PageRiwayat> {
  String cariMitra = "";
  DateTimeRange? selectedRange;
  bool sortTerbaru = true;

  // Track status unduhan per-baris
  final Set<String> _downloadingBatches = {};

  // CACHE DATA FIRESTORE
  int _lastDocHash = 0;
  List<Map<String, dynamic>> _masterBatchList = [];
  List<Map<String, dynamic>> _filteredBatchList = [];

  // STATE PAGINATION
  int _halamanAktif = 1;
  int _barisPerHalaman = 10;
  final List<int> _opsiBaris = [10, 25, 50];

  // ==========================================================
  // 1. FAST DATE PARSER (ULTRA-CEPAT TANPA EXCEPTION)
  // ==========================================================
  static final RegExp _delimiterRegex = RegExp(r'[-/ :T]');

  static DateTime _parseDateSuperFast(dynamic value) {
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

      if (p0 > 1000) {
        return DateTime(p0, p1, p2, hour, minute, second);
      }
      if (p2 > 1000) {
        return DateTime(p2, p1, p0, hour, minute, second);
      }
    }
    return DateTime.tryParse(str) ?? DateTime(1970);
  }

  Uint8List? _safeDecodeBase64(String? base64Str) {
    if (base64Str == null || base64Str.trim().isEmpty) return null;
    try {
      String cleanStr = base64Str.trim();
      if (cleanStr.contains(',')) {
        cleanStr = cleanStr.split(',').last;
      }
      cleanStr = cleanStr.replaceAll('\n', '').replaceAll('\r', '').replaceAll(' ', '');
      return base64Decode(base64.normalize(cleanStr));
    } catch (_) {
      return null;
    }
  }

  // ==========================================================
  // 2. DIALOG PEMILIH TANGGAL ULTRA CEPAT (0 DELAY)
  // ==========================================================
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
                          backgroundColor: const Color(0xFF455A64),
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
      backgroundColor: const Color(0xFFECEFF1),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      onPressed: onTap,
    );
  }

  void _terapkanRentangBaru(DateTimeRange range) {
    setState(() {
      selectedRange = range;
      _halamanAktif = 1;
      _terapkanFilter();
    });
  }

  // ==========================================================
  // 3. CACHING & FILTERING
  // ==========================================================
  void _prosesDataFirestore(List<QueryDocumentSnapshot> docs) {
    final int incomingHash = Object.hashAll(docs.map((d) => d.id));
    if (_lastDocHash == incomingHash) return;

    _lastDocHash = incomingHash;
    _masterBatchList = [];

    for (final doc in docs) {
      final user = doc.data() as Map<String, dynamic>? ?? {};
      if (user['role'] == 'admin') continue;

      final String uidMitra = doc.id;
      final batch = user['batch'] is List ? user['batch'] : [];

      for (final b in batch) {
        if (b is! Map<String, dynamic>) continue;

        final bool isBatchBaru = b.containsKey('batchKode') || b.containsKey('detailTrays');

        if (isBatchBaru) {
          final tglBungkusStr = b['tanggalFormatted']?.toString() ?? "-";
          final tglObj = _parseDateSuperFast(b['tanggalBungkus'] ?? tglBungkusStr);

          _masterBatchList.add({
            'userId': uidMitra,
            'mitra': user['nama'] ?? "Mitra",
            'batchKode': b['batchKode'] ?? "BATCH",
            'tglBungkus': tglBungkusStr,
            'tglObj': tglObj,
            'totalBerat': double.tryParse(b['totalBeratKg']?.toString() ?? '0') ?? 0.0,
            'jumlahTray': b['jumlahTray'] ?? (b['daftarNamaTray'] as List?)?.length ?? 1,
            'status': (b['status']?.toString() ?? "TERBUNGKUS").toUpperCase(),
            'detailTrays': b['detailTrays'] ?? [],
          });
        } else {
          final tglPanenStr = b['tanggalPanen']?.toString() ?? "-";
          final tglObj = _parseDateSuperFast(tglPanenStr);
          _masterBatchList.add({
            'userId': uidMitra,
            'mitra': user['nama'] ?? "Mitra",
            'batchKode': "LEGACY-${b['nama'] ?? 'TRAY'}",
            'tglBungkus': tglPanenStr,
            'tglObj': tglObj,
            'totalBerat': double.tryParse(b['hasilKg']?.toString() ?? '0') ?? 0.0,
            'jumlahTray': 1,
            'status': (b['status']?.toString() ?? "SELESAI").toUpperCase(),
            'detailTrays': [b],
          });
        }
      }
    }
    _terapkanFilter();
  }

  void _terapkanFilter() {
    final query = cariMitra.toLowerCase().trim();

    _filteredBatchList = _masterBatchList.where((item) {
      final bool matchNama = query.isEmpty ||
          item['mitra'].toString().toLowerCase().contains(query) ||
          item['batchKode'].toString().toLowerCase().contains(query);

      bool matchTgl = true;
      if (selectedRange != null) {
        final DateTime d = item['tglObj'];
        final DateTime itemDate = DateTime(d.year, d.month, d.day);
        final DateTime start = DateTime(selectedRange!.start.year, selectedRange!.start.month, selectedRange!.start.day);
        final DateTime end = DateTime(selectedRange!.end.year, selectedRange!.end.month, selectedRange!.end.day);

        matchTgl = !itemDate.isBefore(start) && !itemDate.isAfter(end);
      }

      return matchNama && matchTgl;
    }).toList();

    _filteredBatchList.sort((a, b) {
      final DateTime tglA = a['tglObj'];
      final DateTime tglB = b['tglObj'];
      return sortTerbaru ? tglB.compareTo(tglA) : tglA.compareTo(tglB);
    });
  }

  Future<List<dynamic>> _ambilDetailTraysAsli(Map<String, dynamic> batch) async {
    final List<dynamic> existing = batch['detailTrays'] ?? [];
    if (existing.isNotEmpty) return existing;

    final String userId = batch['userId'] ?? '';
    final String batchKode = batch['batchKode'] ?? '';

    if (userId.isEmpty || batchKode.isEmpty) return [];

    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('batches')
          .doc(batchKode)
          .get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        return docSnapshot.data()!['detailTrays'] ?? [];
      }
    } catch (_) {}

    return [];
  }

  // ==========================================================
  // 4. EXPORT EXCEL TANPA LAG (ISOLATE BACKGROUND)
  // ==========================================================
  Future<void> _exportSingleBatchToExcel(Map<String, dynamic> batch) async {
    final String kodeBatch = batch['batchKode'] ?? 'BATCH';

    if (_downloadingBatches.contains(kodeBatch)) return;

    setState(() {
      _downloadingBatches.add(kodeBatch);
    });

    try {
      final List<dynamic> detailTrays = await _ambilDetailTraysAsli(batch);

      final Map<String, dynamic> params = {
        'batch': batch,
        'detailTrays': detailTrays,
      };

      Uint8List? fileBytes;

      if (kIsWeb) {
        await Future.delayed(const Duration(milliseconds: 40));
        fileBytes = _generateSingleExcelBytes(params);
      } else {
        fileBytes = await compute(_generateSingleExcelBytes, params);
      }

      if (fileBytes == null) throw Exception("Format Excel gagal dibuat.");

      final String namaFileExcel = "Batch_${kodeBatch.replaceAll(RegExp(r'[^\w\s]+'), '_')}.xlsx";

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
            backgroundColor: const Color(0xFF2E7D32),
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

  static Uint8List? _generateSingleExcelBytes(Map<String, dynamic> params) {
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

  // ==========================================================
  // 5. DETAIL TRAY & FOTO
  // ==========================================================
  void _tampilkanDetailTrayDialog(Map<String, dynamic> batch) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final List<dynamic> detail = await _ambilDetailTraysAsli(batch);

    if (!mounted) return;
    Navigator.pop(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("${batch['batchKode']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text("Mitra: ${batch['mitra']} | ${batch['tglBungkus']}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
                    final bool isGagal = t['status'] == "GAGAL";
                    final String gps = t['gps']?.toString() ?? '-';
                    final String namaTray = t['nama'] ?? 'Tray';
                    final String fotoUrl = t['fotoUrl']?.toString() ?? '';
                    final Uint8List? fotoBytes = _safeDecodeBase64(t['fotoBase64']?.toString());
                    final bool hasImage = fotoUrl.isNotEmpty || fotoBytes != null;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      color: isGagal ? const Color(0xFFFFEBEE) : const Color(0xFFFAFAFA),
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
                                        url: fotoUrl,
                                        namaTray: namaTray,
                                        gps: gps,
                                      )
                                  : null,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: fotoBytes != null
                                    ? Image.memory(fotoBytes, width: 65, height: 65, cacheWidth: 140, cacheHeight: 140, fit: BoxFit.cover)
                                    : (fotoUrl.isNotEmpty
                                        ? Image.network(fotoUrl, width: 65, height: 65, cacheWidth: 140, cacheHeight: 140, fit: BoxFit.cover)
                                        : Container(
                                            width: 65,
                                            height: 65,
                                            color: const Color(0xFFE0E0E0),
                                            child: const Icon(Icons.no_photography, size: 24, color: Colors.grey),
                                          )),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(namaTray, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  const SizedBox(height: 2),
                                  Text(
                                    isGagal ? "Status: MATI / GAGAL" : "Hasil: ${t['hasilKg']} Kg (Telur: ${t['beratTelur'] ?? '0'} g)",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isGagal ? Colors.red[800] : Colors.green[800],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text("📍 GPS: $gps", style: const TextStyle(fontSize: 11, color: Colors.black87)),
                                  Text(
                                    "🗓️ Mulai: ${t['tglMulaiFormatted'] ?? '-'} | Panen: ${t['tanggalPanen'] ?? '-'}",
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

  void _tampilkanFotoBesar(BuildContext context, {Uint8List? bytes, String? url, required String namaTray, required String gps}) {
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
                        ? Image.memory(bytes, fit: BoxFit.contain)
                        : (url != null && url.isNotEmpty
                            ? Image.network(url, fit: BoxFit.contain)
                            : const Center(child: Icon(Icons.no_photography, size: 50, color: Colors.grey))),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(8)),
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

  // ==========================================================
  // 6. BUILD UI UTAMA
  // ==========================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _masterBatchList.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Terjadi kesalahan: ${snapshot.error}"));
          }

          if (snapshot.hasData) {
            _prosesDataFirestore(snapshot.data!.docs);
          }

          final int totalData = _filteredBatchList.length;
          final int totalHalaman = totalData == 0 ? 1 : (totalData / _barisPerHalaman).ceil();

          if (_halamanAktif > totalHalaman) _halamanAktif = totalHalaman;
          if (_halamanAktif < 1) _halamanAktif = 1;

          final int startIndex = (totalData == 0) ? 0 : (_halamanAktif - 1) * _barisPerHalaman;
          final int endIndex = min(startIndex + _barisPerHalaman, totalData);
          final List<Map<String, dynamic>> dataHalamanIni =
              (totalData == 0) ? [] : _filteredBatchList.sublist(startIndex, endIndex);

          return Column(
            children: [
              // ==========================================
              // TOOLBAR ATAS: CARI, TOGGLE & TANGGAL
              // ==========================================
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Row(
                  children: [
                    // PENCARIAN
                    Expanded(
                      child: TextField(
                        onChanged: (v) {
                          cariMitra = v;
                          _halamanAktif = 1;
                          setState(() {
                            _terapkanFilter();
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

                    // SEGMENTED TOGGLE (TERBARU / TERLAMA) - SANGAT MULUS TANPA LAG
                    Container(
                      height: 44,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECEFF1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () {
                              if (sortTerbaru) return;
                              setState(() {
                                sortTerbaru = true;
                                _halamanAktif = 1;
                                _filteredBatchList = _filteredBatchList.reversed.toList();
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: sortTerbaru ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: sortTerbaru
                                    ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))]
                                    : null,
                              ),
                              child: Text(
                                "Terbaru",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: sortTerbaru ? FontWeight.bold : FontWeight.w500,
                                  color: sortTerbaru ? const Color(0xFF1565C0) : const Color(0xFF546E7A),
                                ),
                              ),
                            ),
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () {
                              if (!sortTerbaru) return;
                              setState(() {
                                sortTerbaru = false;
                                _halamanAktif = 1;
                                _filteredBatchList = _filteredBatchList.reversed.toList();
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: !sortTerbaru ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: !sortTerbaru
                                    ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))]
                                    : null,
                              ),
                              child: Text(
                                "Terlama",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: !sortTerbaru ? FontWeight.bold : FontWeight.w500,
                                  color: !sortTerbaru ? const Color(0xFFE65100) : const Color(0xFF546E7A),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // TOMBOL FILTER TANGGAL INSTAN
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
                        backgroundColor: const Color(0xFF455A64),
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
                            _terapkanFilter();
                          });
                        },
                        icon: const Icon(Icons.close, color: Colors.red),
                      ),
                    ]
                  ],
                ),
              ),

              const Divider(height: 1, thickness: 1),

              // TABEL DATA UTAMA
              Expanded(
                child: dataHalamanIni.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 50, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text("Data batch tidak ditemukan", style: TextStyle(color: Colors.grey[600])),
                          ],
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF5F5F5)),
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
                                    final String batchCode = item['batchKode'] ?? '';
                                    final bool isDownloading = _downloadingBatches.contains(batchCode);

                                    return DataRow(
                                      cells: [
                                        DataCell(Text(item['mitra'], style: const TextStyle(fontWeight: FontWeight.w600))),
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.blueGrey.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(5),
                                            ),
                                            child: Text(batchCode, style: const TextStyle(fontWeight: FontWeight.bold)),
                                          ),
                                        ),
                                        DataCell(Text(item['tglBungkus'])),
                                        DataCell(Text("${item['jumlahTray']} Tray", style: const TextStyle(fontWeight: FontWeight.w500))),
                                        DataCell(
                                          Text(
                                            "${item['totalBerat']} Kg",
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1565C0)),
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
                                                        child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF2E7D32)),
                                                      ),
                                                    )
                                                  : IconButton(
                                                      icon: const Icon(Icons.file_download_outlined, color: Color(0xFF2E7D32)),
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
                      ),
              ),

              const Divider(height: 1, thickness: 1),

              // PAGINATION BAR
              _buildPaginationBar(totalData, totalHalaman, startIndex, endIndex),

              const Divider(height: 1, thickness: 1),

              // FOOTER
              _buildFooter(_filteredBatchList),
            ],
          );
        },
      ),
    );
  }

  // ==========================================================
  // 7. KONTROL PAGINATION
  // ==========================================================
  Widget _buildPaginationBar(int totalData, int totalHalaman, int startIndex, int endIndex) {
    List<int> nomorHalaman = [];
    int startPage = max(1, _halamanAktif - 2);
    int endPage = min(totalHalaman, startPage + 4);

    if (endPage - startPage < 4) {
      startPage = max(1, endPage - 4);
    }

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
                      backgroundColor: isActive ? const Color(0xFF455A64) : Colors.transparent,
                      side: BorderSide(
                        color: isActive ? const Color(0xFF455A64) : const Color(0xFFE0E0E0),
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

  // ==========================================================
  // 8. FOOTER STATISTIK
  // ==========================================================
  Widget _buildFooter(List<Map<String, dynamic>> data) {
    double totalKg = data.fold(0.0, (acc, item) => acc + (double.tryParse(item['totalBerat'].toString()) ?? 0));
    int totalTray = data.fold(0, (acc, item) => acc + (int.tryParse(item['jumlahTray'].toString()) ?? 0));

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
              color: Color(0xFF1A237E),
            ),
          ),
        ],
      ),
    );
  }
}