// page_Estimasi.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../backend/estimasi/data_estimasi.dart';
import '../../backend/estimasi/pembaca_estimasi.dart';
import '../../backend/estimasi/pembuat_laporan_estimasi.dart';
import '../../backend/estimasi/penyaring_estimasi.dart';
import 'tema_estimasi.dart';
import 'widget/dialog_filter_tanggal.dart';
import 'widget/tampilan_footer_estimasi.dart';
import 'widget/tampilan_pagination_estimasi.dart';
import 'widget/tampilan_tabel_estimasi.dart';
import 'widget/tampilan_toolbar_estimasi.dart';

// ============================================================================
// 1. HALAMAN ESTIMASI (ADMIN) — PLUG & PLAY
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
  List<DataEstimasi> _cachedRawItems = [];

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
      _startDateKey = PembacaEstimasi.toIntegerDate(range.start);
      _endDateKey = PembacaEstimasi.toIntegerDate(range.end);
      _halamanAktif = 1;
    });
  }

  List<DataEstimasi> _dapatkanDataParsed(List<QueryDocumentSnapshot> docs) {
    if (identical(_cachedDocs, docs)) {
      return _cachedRawItems;
    }
    _cachedDocs = docs;
    _cachedRawItems = PembacaEstimasi.parseFirestoreDocuments(docs);
    return _cachedRawItems;
  }

  Future<void> _exportToExcel(List<DataEstimasi> data) async {
    if (_isExporting || _isExportSuccess || data.isEmpty) return;

    setState(() {
      _isExporting = true;
    });

    // 🚀 Beri jeda 100ms agar event loop merender efek tombol tanpa lag
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      await PembuatLaporanEstimasi.exportAndOpenFile(
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
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => DialogFilterTanggal(
        rangeAkhir: _selectedRange,
        onTerapkan: _terapkanRentangBaru,
      ),
    );
  }

  void _hapusFilterTanggal() {
    setState(() {
      _selectedRange = null;
      _startDateKey = null;
      _endDateKey = null;
      _halamanAktif = 1;
    });
  }

  void _onSortChange(bool value) {
    setState(() {
      _sortTerbaru = value;
      _halamanAktif = 1;
    });
  }

  // ==========================================================
  // USER INTERFACE
  // ==========================================================
  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: TemaEstimasi.background,
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

          final List<DataEstimasi> filtered = PenyaringEstimasi.terapkanFilter(
            data: rawItems,
            cariMitra: _cariMitra,
            startDateKey: filterTgl ? startK : null,
            endDateKey: filterTgl ? endK : null,
          );

          final List<DataEstimasi> sorted =
              PenyaringEstimasi.mengurutkan(data: filtered, sortTerbaru: _sortTerbaru);

          final int totalData = sorted.length;
          final int totalHalaman = totalData == 0 ? 1 : (totalData / _barisPerHalaman).ceil();

          if (_halamanAktif > totalHalaman) _halamanAktif = totalHalaman;
          if (_halamanAktif < 1) _halamanAktif = 1;

          final int startIndex = (totalData == 0) ? 0 : (_halamanAktif - 1) * _barisPerHalaman;
          final int endIndex = min(startIndex + _barisPerHalaman, totalData);
          final List<DataEstimasi> dataHalamanIni =
              (totalData == 0) ? [] : sorted.sublist(startIndex, endIndex);

          return Column(
            children: [
              TampilanToolbarEstimasi(
                controller: _searchController,
                onCariChanged: _onSearchChanged,
                sortTerbaru: _sortTerbaru,
                onSortChange: _onSortChange,
                selectedRange: _selectedRange,
                onBukaFilterTanggal: () => _bukaFilterTanggalCepat(context),
                onHapusFilterTanggal: _hapusFilterTanggal,
              ),
              const Divider(height: 1, thickness: 1),
              Expanded(
                child: TampilanTabelEstimasi(dataHalamanIni: dataHalamanIni),
              ),
              const Divider(height: 1, thickness: 1),
              TampilanPaginationEstimasi(
                totalData: totalData,
                totalHalaman: totalHalaman,
                startIndex: startIndex,
                endIndex: endIndex,
                halamanAktif: _halamanAktif,
                barisPerHalaman: _barisPerHalaman,
                opsiBaris: _opsiBaris,
                onHalamanChange: (page) {
                  setState(() {
                    _halamanAktif = page;
                  });
                },
                onBarisChange: (val) {
                  setState(() {
                    _barisPerHalaman = val;
                    _halamanAktif = 1;
                  });
                },
              ),
              const Divider(height: 1, thickness: 1),
              TampilanFooterEstimasi(
                data: sorted,
                sedangExport: _isExporting,
                exportSuccess: _isExportSuccess,
                onExport: _exportToExcel,
              ),
            ],
          );
        },
      ),
    );
  }
}
