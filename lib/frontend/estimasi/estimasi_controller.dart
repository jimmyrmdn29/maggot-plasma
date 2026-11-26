import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../backend/estimasi/data_estimasi.dart';
import '../../backend/estimasi/pembaca_estimasi.dart';
import '../../backend/estimasi/pembuat_laporan_estimasi.dart';
import '../../backend/estimasi/penyaring_estimasi.dart';

// ============================================================================
// VIEWMODEL: ESTIMASI PANEN (state + flow, tanpa widget)
// ============================================================================
class EstimasiController extends ChangeNotifier {
  EstimasiController({
    required this.onSnackbar,
  }) {
    _usersStream = FirebaseFirestore.instance.collection('users').snapshots();
  }

  final void Function(String msg, {bool isError}) onSnackbar;

  late final Stream<QuerySnapshot> _usersStream;
  List<QueryDocumentSnapshot>? _cachedDocs;
  List<DataEstimasi> _cachedRawItems = [];

  final TextEditingController searchController = TextEditingController();
  Timer? _debounceTimer;
  String _cariMitra = '';
  DateTimeRange? _selectedRange;
  int? _startDateKey;
  int? _endDateKey;

  bool _sortTerbaru = true;
  bool _isExporting = false;
  bool _isExportSuccess = false;

  int _halamanAktif = 1;
  int _barisPerHalaman = 10;
  static const List<int> opsiBaris = [10, 25, 50];

  // ---------- getters ----------
  Stream<QuerySnapshot> get usersStream => _usersStream;
  String get cariMitra => _cariMitra;
  DateTimeRange? get selectedRange => _selectedRange;
  bool get sortTerbaru => _sortTerbaru;
  bool get isExporting => _isExporting;
  bool get isExportSuccess => _isExportSuccess;
  int get halamanAktif => _halamanAktif;
  int get barisPerHalaman => _barisPerHalaman;

  List<DataEstimasi> _dapatkanDataParsed(List<QueryDocumentSnapshot> docs) {
    if (identical(_cachedDocs, docs)) {
      return _cachedRawItems;
    }
    _cachedDocs = docs;
    _cachedRawItems = PembacaEstimasi.parseFirestoreDocuments(docs);
    return _cachedRawItems;
  }

  List<DataEstimasi> _filtered = [];
  List<DataEstimasi> _sorted = [];

  List<DataEstimasi> get filtered => _filtered;
  List<DataEstimasi> get sorted => _sorted;

  List<DataEstimasi> parseAndFilter(List<QueryDocumentSnapshot> docs) {
    final rawItems = _dapatkanDataParsed(docs);
    final bool filterTgl = _startDateKey != null && _endDateKey != null;
    final int startK = _startDateKey ?? 0;
    final int endK = _endDateKey ?? 0;

    _filtered = PenyaringEstimasi.terapkanFilter(
      data: rawItems,
      cariMitra: _cariMitra,
      startDateKey: filterTgl ? startK : null,
      endDateKey: filterTgl ? endK : null,
    );
    _sorted = PenyaringEstimasi.mengurutkan(data: _filtered, sortTerbaru: _sortTerbaru);

    final int totalData = _sorted.length;
    final int totalHalaman = totalData == 0 ? 1 : (totalData / _barisPerHalaman).ceil();
    if (_halamanAktif > totalHalaman) _halamanAktif = totalHalaman;
    if (_halamanAktif < 1) _halamanAktif = 1;

    return _sorted;
  }

  int get totalData => _sorted.length;
  int get totalHalaman => totalData == 0 ? 1 : (totalData / _barisPerHalaman).ceil();
  int get startIndex => (totalData == 0) ? 0 : (_halamanAktif - 1) * _barisPerHalaman;
  int get endIndex => min(startIndex + _barisPerHalaman, totalData);
  List<DataEstimasi> get dataHalamanIni =>
      (totalData == 0) ? [] : _sorted.sublist(startIndex, endIndex);

  // ---------- flow ----------
  void onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 150), () {
      _cariMitra = query.trim().toLowerCase();
      _halamanAktif = 1;
      notifyListeners();
    });
  }

  void terapkanRentangBaru(DateTimeRange range) {
    _selectedRange = range;
    _startDateKey = PembacaEstimasi.toIntegerDate(range.start);
    _endDateKey = PembacaEstimasi.toIntegerDate(range.end);
    _halamanAktif = 1;
    notifyListeners();
  }

  void hapusFilterTanggal() {
    _selectedRange = null;
    _startDateKey = null;
    _endDateKey = null;
    _halamanAktif = 1;
    notifyListeners();
  }

  void onSortChange(bool value) {
    _sortTerbaru = value;
    _halamanAktif = 1;
    notifyListeners();
  }

  void onHalamanChange(int page) {
    _halamanAktif = page;
    notifyListeners();
  }

  void onBarisChange(int val) {
    _barisPerHalaman = val;
    _halamanAktif = 1;
    notifyListeners();
  }

  Future<void> exportToExcel(List<DataEstimasi> data) async {
    if (_isExporting || _isExportSuccess || data.isEmpty) return;

    _isExporting = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 100));

    try {
      await PembuatLaporanEstimasi.exportAndOpenFile(
        data: data,
        selectedRange: _selectedRange,
      );

      _isExporting = false;
      _isExportSuccess = true;
      notifyListeners();

      Future.delayed(const Duration(milliseconds: 1500), () {
        _isExportSuccess = false;
        notifyListeners();
      });
    } catch (e) {
      _isExporting = false;
      notifyListeners();
      onSnackbar("Gagal mengunduh: $e", isError: true);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    searchController.dispose();
    super.dispose();
  }
}
