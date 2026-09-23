// page_Estimasi.dart
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'app_config.dart'; // ⚙️ HARI_AUTO_PANEN & ESTIMASI_RASIO_TELUR_KE_HASIL

// ============================================================================
// 1. DESIGN SYSTEM / CONSTANTS
// ============================================================================
class _EstimasiTheme {
  static const Color primary = Color(0xFF1A237E);
  static const Color success = Color(0xFF2E7D32);
  static const Color successDark = Color(0xFF1B5E20);
  static const Color warning = Color(0xFFE65100);
  static const Color textMuted = Color(0xFF546E7A);
  static const Color background = Color(0xFFF9FAFB);
  static const Color surfaceGrey = Color(0xFFECEFF1);
  static const Color tableHeaderBg = Color(0xFFF5F5F5);
  static const Color borderGrey = Color(0xFFE0E0E0);
}

// ============================================================================
// 2. DATA MODEL (ENTITY)
// ============================================================================
class EstimasiItem {
  final String nama;
  final String tray;
  final double telur;
  final String tglMulaiStr;
  final DateTime tglObj;
  final int dateKey;
  final String tglEstimasiStr;
  final double estimasiKg;
  final String searchableText;

  EstimasiItem({
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

// ============================================================================
// 3. SERVICE: EXCEL ENGINE & I/O
// ============================================================================
class EstimasiExcelService {
  static excel_pkg.Excel createExcelDocument(List<dynamic> data, String infoPeriode) {
    final excel = excel_pkg.Excel.createExcel();
    final String sheetName = excel.getDefaultSheet() ?? 'Sheet1';
    final sheet = excel[sheetName];

    double total = 0.0;

    sheet.appendRow([excel_pkg.TextCellValue("LAPORAN ESTIMASI PANEN MITRA")]);
    sheet.appendRow([excel_pkg.TextCellValue("PERIODE RENTANG:"), excel_pkg.TextCellValue(infoPeriode)]);
    sheet.appendRow([excel_pkg.TextCellValue("DIUNDUH PADA:"), excel_pkg.TextCellValue(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()))]);
    sheet.appendRow([excel_pkg.TextCellValue("")]);

    sheet.appendRow([
      excel_pkg.TextCellValue("NO"),
      excel_pkg.TextCellValue("NAMA MITRA"),
      excel_pkg.TextCellValue("NAMA TRAY"),
      excel_pkg.TextCellValue("TELUR (G)"),
      excel_pkg.TextCellValue("TGL MULAI"),
      excel_pkg.TextCellValue("ESTIMASI PANEN"),
      excel_pkg.TextCellValue("ESTIMASI HASIL (KG)"),
    ]);

    int no = 1;
    for (final raw in data) {
      try {
        if (raw is! Map<String, dynamic>) continue;

        final double beratEst = double.tryParse(raw['estimasi']?.toString() ?? '0') ?? 0.0;
        final double telurG = double.tryParse(raw['telur']?.toString() ?? '0') ?? 0.0;
        total += beratEst;

        sheet.appendRow([
          excel_pkg.IntCellValue(no++),
          excel_pkg.TextCellValue(raw['nama']?.toString() ?? "-"),
          excel_pkg.TextCellValue(raw['tray']?.toString() ?? "-"),
          excel_pkg.TextCellValue("${telurG.toStringAsFixed(1)} g"),
          excel_pkg.TextCellValue(raw['tglMulai']?.toString() ?? "-"),
          excel_pkg.TextCellValue(raw['tglEstimasi']?.toString() ?? "-"),
          excel_pkg.DoubleCellValue(double.parse(beratEst.toStringAsFixed(2))),
        ]);
      } catch (e) {
        debugPrint("Error baris Excel: $e");
        continue;
      }
    }

    sheet.appendRow([
      excel_pkg.TextCellValue("TOTAL ESTIMASI"),
      excel_pkg.TextCellValue(""),
      excel_pkg.TextCellValue(""),
      excel_pkg.TextCellValue(""),
      excel_pkg.TextCellValue(""),
      excel_pkg.TextCellValue(""),
      excel_pkg.DoubleCellValue(double.parse(total.toStringAsFixed(2))),
    ]);

    return excel;
  }

  static Uint8List? generateExcelWorker(Map<String, dynamic> params) {
    try {
      final excel = createExcelDocument(params['data'], params['infoPeriode']);
      final bytes = excel.encode();
      if (bytes == null) return null;
      return Uint8List.fromList(bytes);
    } catch (e) {
      debugPrint("Isolate Excel Error: $e");
      return null;
    }
  }

  static Future<void> exportAndOpenFile({
    required List<EstimasiItem> data,
    required DateTimeRange? selectedRange,
  }) async {
    final DateFormat dfExport = DateFormat('dd-MM-yyyy');
    final String infoPeriode = selectedRange != null
        ? "${dfExport.format(selectedRange.start)} s/d ${dfExport.format(selectedRange.end)}"
        : "Semua Tanggal (Unduh: ${dfExport.format(DateTime.now())})";
    final String namaFile = "Estimasi_Panen_${infoPeriode.replaceAll(' ', '_')}.xlsx";

    final exportData = data.map((e) => e.toExportMap()).toList();

    if (kIsWeb) {
      final excel = createExcelDocument(exportData, infoPeriode);
      final bytes = excel.encode();
      if (bytes == null) throw Exception("Gagal encode Excel");
      excel.save(fileName: namaFile);
    } else {
      final Uint8List? fileBytes = await compute(generateExcelWorker, {
        'data': exportData,
        'infoPeriode': infoPeriode,
      });

      if (fileBytes == null) throw Exception("Gagal generate Excel bytes");

      final Directory appDir = await getApplicationDocumentsDirectory();
      final String pathFile = '${appDir.path}/$namaFile';
      final File file = File(pathFile);
      await file.writeAsBytes(fileBytes, flush: true);
      await OpenFilex.open(pathFile);
    }
  }
}

// ============================================================================
// 4. BUSINESS LOGIC & PARSER LAYER
// ============================================================================
class EstimasiParser {
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  static int toIntegerDate(DateTime date) {
    return date.year * 10000 + date.month * 100 + date.day;
  }

  static List<EstimasiItem> parseFirestoreDocuments(List<QueryDocumentSnapshot> docs) {
    final List<EstimasiItem> parsedList = [];

    for (final doc in docs) {
      try {
        final user = doc.data() as Map<String, dynamic>? ?? {};
        if (user['role'] == 'admin') continue;

        final dynamic siklusRaw = user['siklus'];
        if (siklusRaw is! List || siklusRaw.isEmpty) continue;

        final String namaUser = user['nama']?.toString() ?? "Mitra";

        // 🛡️ 1. Kumpulkan daftar tray yang sudah dipanen / ada di batch
        final dynamic batchRaw = user['batch'];
        final Set<String> traySudahPanen = {};
        if (batchRaw is List) {
          for (final b in batchRaw) {
            if (b is! Map<String, dynamic>) continue;
            final detail = b['detailTrays'];
            if (detail is List) {
              for (final dt in detail) {
                if (dt is Map && dt['nama'] != null) {
                  traySudahPanen.add(dt['nama'].toString().trim().toLowerCase());
                }
              }
            }
            if (b['nama'] != null) {
              traySudahPanen.add(b['nama'].toString().trim().toLowerCase());
            }
          }
        }

        // 🛡️ 2. Iterasi siklus aktif
        for (final s in siklusRaw) {
          if (s is! Map<String, dynamic>) continue;

          final String namaTray = s['nama']?.toString() ?? "-";

          if (traySudahPanen.contains(namaTray.trim().toLowerCase())) {
            continue;
          }

          final String statusSiklus = (s['status'] ?? '').toString().toLowerCase();
          if (statusSiklus == 'selesai' || statusSiklus == 'panen' || s['isPanen'] == true) {
            continue;
          }

          final rawTgl = s['tanggalMulai'];
          if (rawTgl == null) continue;

          DateTime tglMulai;
          if (rawTgl is Timestamp) {
            tglMulai = rawTgl.toDate();
          } else if (rawTgl is DateTime) {
            tglMulai = rawTgl;
          } else {
            tglMulai = DateTime.tryParse(rawTgl.toString()) ?? DateTime.now();
          }

          final DateTime tglEst = tglMulai.add(Duration(days: HARI_AUTO_PANEN));
          final double beratTelur = double.tryParse(s['beratTelur']?.toString() ?? '0') ?? 0.0;
          final double hasilEst = beratTelur * ESTIMASI_RASIO_TELUR_KE_HASIL;

          parsedList.add(
            EstimasiItem(
              nama: namaUser,
              tray: namaTray,
              telur: beratTelur,
              tglMulaiStr: _dateFormat.format(tglMulai),
              tglObj: tglEst,
              dateKey: toIntegerDate(tglEst),
              tglEstimasiStr: _dateFormat.format(tglEst),
              estimasiKg: hasilEst,
            ),
          );
        }
      } catch (e) {
        debugPrint("Error parse doc ${doc.id}: $e");
        continue;
      }
    }

    return parsedList;
  }
}

// ============================================================================
// 5. WIDGET UTAMA (PRESENTATION LAYER)
// ============================================================================
class PageEstimasi extends StatefulWidget {
  const PageEstimasi({super.key});

  @override
  State<PageEstimasi> createState() => _PageEstimasiState();
}

class _PageEstimasiState extends State<PageEstimasi> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final Stream<QuerySnapshot> _usersStream;
  List<QueryDocumentSnapshot>? _cachedDocs;
  List<EstimasiItem> _cachedRawItems = [];

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  String _cariMitra = "";
  DateTimeRange? _selectedRange;
  int? _startDateKey;
  int? _endDateKey;

  bool _sortTerbaru = true;
  bool _isExporting = false;
  bool _isExportSuccess = false;

  int _halamanAktif = 1;
  int _barisPerHalaman = 10;
  static const List<int> _opsiBaris = [10, 25, 50];

  @override
  void initState() {
    super.initState();
    _usersStream = FirebaseFirestore.instance.collection('users').snapshots();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() {
          _cariMitra = query.trim().toLowerCase();
          _halamanAktif = 1;
        });
      }
    });
  }

  void _terapkanRentangBaru(DateTimeRange range) {
    setState(() {
      _selectedRange = range;
      _startDateKey = EstimasiParser.toIntegerDate(range.start);
      _endDateKey = EstimasiParser.toIntegerDate(range.end);
      _halamanAktif = 1;
    });
  }

  List<EstimasiItem> _dapatkanDataParsed(List<QueryDocumentSnapshot> docs) {
    if (identical(_cachedDocs, docs)) {
      return _cachedRawItems;
    }
    _cachedDocs = docs;
    _cachedRawItems = EstimasiParser.parseFirestoreDocuments(docs);
    return _cachedRawItems;
  }

  Future<void> _exportToExcel(List<EstimasiItem> data) async {
    if (_isExporting || _isExportSuccess || data.isEmpty) return;

    setState(() {
      _isExporting = true;
    });

    // 🚀 Beri jeda 100ms agar event loop merender efek tombol tanpa lag
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      await EstimasiExcelService.exportAndOpenFile(
        data: data,
        selectedRange: _selectedRange,
      );

      if (mounted) {
        setState(() {
          _isExporting = false;
          _isExportSuccess = true;
        });

        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) setState(() => _isExportSuccess = false);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal mengunduh: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _bukaFilterTanggalCepat(BuildContext context) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTime tempStart = _selectedRange?.start ?? today;
    DateTime tempEnd = _selectedRange?.end ?? today.add(const Duration(days: 7));

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
                          "Pilih Jadwal Estimasi Panen",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        )
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "JADWAL ESTIMASI CEPAT",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildPresetChip("Hari Ini", () {
                          _terapkanRentangBaru(DateTimeRange(start: today, end: today));
                          Navigator.pop(ctx);
                        }),
                        _buildPresetChip("7 Hari Ke Depan", () {
                          final end = today.add(const Duration(days: 6));
                          _terapkanRentangBaru(DateTimeRange(start: today, end: end));
                          Navigator.pop(ctx);
                        }),
                        _buildPresetChip("Bulan Ini", () {
                          final start = today;
                          final end = DateTime(now.year, now.month + 1, 0);
                          _terapkanRentangBaru(DateTimeRange(start: start, end: end));
                          Navigator.pop(ctx);
                        }),
                        _buildPresetChip("Bulan Depan", () {
                          final start = DateTime(now.year, now.month + 1, 1);
                          final end = DateTime(now.year, now.month + 2, 0);
                          _terapkanRentangBaru(DateTimeRange(start: start, end: end));
                          Navigator.pop(ctx);
                        }),
                      ],
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Divider(height: 1),
                    ),

                    const Text(
                      "RENTANG KUSTOM",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: tempStart,
                                firstDate: today.subtract(const Duration(days: 30)),
                                lastDate: today.add(const Duration(days: 365)),
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
                                  const Text("Mulai Estimasi", style: TextStyle(fontSize: 10, color: Colors.grey)),
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
                                lastDate: today.add(const Duration(days: 365)),
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
                                  const Text("Sampai Estimasi", style: TextStyle(fontSize: 10, color: Colors.grey)),
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
                          backgroundColor: _EstimasiTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          _terapkanRentangBaru(DateTimeRange(start: tempStart, end: tempEnd));
                          Navigator.pop(ctx);
                        },
                        child: const Text("TERAPKAN RENTANG ESTIMASI", style: TextStyle(fontWeight: FontWeight.bold)),
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
      backgroundColor: _EstimasiTheme.surfaceGrey,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      onPressed: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: _EstimasiTheme.background,
      body: StreamBuilder<QuerySnapshot>(
        stream: _usersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _cachedDocs == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Terjadi kesalahan: ${snapshot.error}"));
          }

          final rawDocs = snapshot.data?.docs ?? _cachedDocs ?? [];
          final rawItems = _dapatkanDataParsed(rawDocs);

          final bool filterTgl = _startDateKey != null && _endDateKey != null;
          final int startK = _startDateKey ?? 0;
          final int endK = _endDateKey ?? 0;

          final filtered = rawItems.where((item) {
            if (_cariMitra.isNotEmpty && !item.searchableText.contains(_cariMitra)) {
              return false;
            }
            if (filterTgl && (item.dateKey < startK || item.dateKey > endK)) {
              return false;
            }
            return true;
          }).toList();

          filtered.sort((a, b) => _sortTerbaru
              ? b.dateKey.compareTo(a.dateKey)
              : a.dateKey.compareTo(b.dateKey));

          final int totalData = filtered.length;
          final int totalHalaman = totalData == 0 ? 1 : (totalData / _barisPerHalaman).ceil();

          if (_halamanAktif > totalHalaman) _halamanAktif = totalHalaman;
          if (_halamanAktif < 1) _halamanAktif = 1;

          final int startIndex = (totalData == 0) ? 0 : (_halamanAktif - 1) * _barisPerHalaman;
          final int endIndex = min(startIndex + _barisPerHalaman, totalData);
          final List<EstimasiItem> dataHalamanIni =
              (totalData == 0) ? [] : filtered.sublist(startIndex, endIndex);

          return Column(
            children: [
              _buildSearchBar(context),
              const Divider(height: 1, thickness: 1),
              Expanded(child: _buildTable(dataHalamanIni)),
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
  // 6. UI SUB-COMPONENTS
  // ==========================================================================
  Widget _buildSearchBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: "Cari nama mitra / nama tray...",
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged("");
                        },
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 12),

          Container(
            height: 44,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: _EstimasiTheme.surfaceGrey,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSortTab(
                  label: "Terbaru",
                  isActive: _sortTerbaru,
                  activeColor: _EstimasiTheme.primary,
                  onTap: () {
                    if (_sortTerbaru) return;
                    setState(() {
                      _sortTerbaru = true;
                      _halamanAktif = 1;
                    });
                  },
                ),
                _buildSortTab(
                  label: "Terlama",
                  isActive: !_sortTerbaru,
                  activeColor: _EstimasiTheme.warning,
                  onTap: () {
                    if (!_sortTerbaru) return;
                    setState(() {
                      _sortTerbaru = false;
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
              _selectedRange == null
                  ? "JADWAL ESTIMASI"
                  : "${DateFormat('dd/MM').format(_selectedRange!.start)} - ${DateFormat('dd/MM').format(_selectedRange!.end)}",
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              backgroundColor: _EstimasiTheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          if (_selectedRange != null) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: "Hapus Filter Tanggal",
              onPressed: () => setState(() {
                _selectedRange = null;
                _startDateKey = null;
                _endDateKey = null;
                _halamanAktif = 1;
              }),
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
            color: isActive ? activeColor : _EstimasiTheme.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildTable(List<EstimasiItem> dataHalamanIni) {
    if (dataHalamanIni.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy_outlined, size: 50, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text("Data estimasi panen tidak ditemukan", style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const double minTabelWidth = 850;
        final double tableWidth = max(constraints.maxWidth, minTabelWidth);

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: SizedBox(
            width: tableWidth,
            child: Column(
              children: [
                Container(
                  height: 48,
                  color: _EstimasiTheme.tableHeaderBg,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Row(
                    children: [
                      Expanded(flex: 3, child: Text("NAMA MITRA", style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text("NAMA TRAY", style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text("TELUR", style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text("TGL MULAI", style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text("EST. PANEN", style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text("EST. HASIL", style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: dataHalamanIni.length,
                    itemExtent: 52,
                    itemBuilder: (context, index) {
                      final item = dataHalamanIni[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                item.nama,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blueGrey.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    item.tray,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text("${item.telur.toStringAsFixed(1)} g"),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(item.tglMulaiStr),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                item.tglEstimasiStr,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: _EstimasiTheme.success),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                "${item.estimasiKg.toStringAsFixed(1)} Kg",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1565C0),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
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
                    : "Menampilkan ${startIndex + 1} - $endIndex dari $totalData tray",
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
                      backgroundColor: isActive ? _EstimasiTheme.primary : Colors.transparent,
                      side: BorderSide(
                        color: isActive ? _EstimasiTheme.primary : _EstimasiTheme.borderGrey,
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

  Widget _buildFooter(List<EstimasiItem> data) {
    final double total = data.fold(0.0, (sum, item) => sum + item.estimasiKg);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_outlined, color: _EstimasiTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                "Total Record: ${data.length} Tray",
                style: const TextStyle(fontSize: 13, color: Color(0xFF424242), fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Text(
                "Total Estimasi: ${total.toStringAsFixed(1)} Kg",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: _EstimasiTheme.primary,
                ),
              ),
              const SizedBox(width: 20),
              ElevatedButton.icon(
                onPressed: (data.isEmpty || _isExporting) ? null : () => _exportToExcel(data),
                icon: Icon(
                  _isExportSuccess ? Icons.check_circle : Icons.file_download_outlined,
                  size: 18,
                  color: Colors.white,
                ),
                label: Text(
                  _isExportSuccess ? "BERHASIL!" : "UNDUH EXCEL",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isExportSuccess ? _EstimasiTheme.successDark : _EstimasiTheme.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}