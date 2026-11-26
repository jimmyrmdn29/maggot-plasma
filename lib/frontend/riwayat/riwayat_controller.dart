import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../backend/riwayat/rincian_tray.dart';
import '../../backend/riwayat/data_batch.dart';
import '../../backend/riwayat/pembaca_riwayat.dart';
import '../../backend/riwayat/pembuat_laporan_riwayat.dart';
import 'theme_riwayat.dart';

// ============================================================================
// VIEWMODEL: RIWAYAT PANEN (state + flow, tanpa widget)
// ============================================================================
class RiwayatController extends ChangeNotifier {
  RiwayatController({
    required this.onSnackbar,
  }) {
    _usersStream = FirebaseFirestore.instance.collection('users').snapshots();
  }

  final void Function(String msg, {bool isError, Color? color}) onSnackbar;

  final TextEditingController searchController = TextEditingController();
  late final Stream<QuerySnapshot> _usersStream;
  Stream<QuerySnapshot> get usersStream => _usersStream;

  String cariMitra = '';
  DateTimeRange? selectedRange;
  bool sortTerbaru = true;

  final Set<String> _downloadingBatches = {};
  Set<String> get downloadingBatches => _downloadingBatches;

  int _lastDocHash = 0;
  List<DataBatch> _cachedMasterList = [];

  int _halamanAktif = 1;
  int _barisPerHalaman = 10;
  static const List<int> opsiBaris = [10, 25, 50];

  int get halamanAktif => _halamanAktif;
  int get barisPerHalaman => _barisPerHalaman;

  void onSearchChanged(String value) {
    // debounce dilakukan di UI; di sini langsung update
    cariMitra = value.trim().toLowerCase();
    _halamanAktif = 1;
    notifyListeners();
  }

  void terapkanRentangBaru(DateTimeRange range) {
    selectedRange = range;
    _halamanAktif = 1;
    notifyListeners();
  }

  void hapusFilterTanggal() {
    selectedRange = null;
    _halamanAktif = 1;
    notifyListeners();
  }

  void onSortChange(bool value) {
    sortTerbaru = value;
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

  // ---------- parsing + cache ----------
  List<DataBatch> parseMasterList(List<QueryDocumentSnapshot> docs) {
    final int currentHash = Object.hashAll(docs.map((d) => d.id));
    if (currentHash == _lastDocHash && _cachedMasterList.isNotEmpty) {
      return _cachedMasterList;
    }
    _lastDocHash = currentHash;
    _cachedMasterList = PembacaRiwayat.parseFirestoreDocs(docs);
    return _cachedMasterList;
  }

  List<DataBatch> get filtered {
    var list = List<DataBatch>.from(_cachedMasterList);

    if (cariMitra.isNotEmpty) {
      list.removeWhere((b) =>
          !b.mitra.toLowerCase().contains(cariMitra) &&
          !b.batchKode.toLowerCase().contains(cariMitra));
    }

    if (selectedRange != null) {
      list.removeWhere((b) {
        final DateTime d = b.tglObj;
        final DateTime itemDate = DateTime(d.year, d.month, d.day);
        final DateTime start = DateTime(selectedRange!.start.year, selectedRange!.start.month, selectedRange!.start.day);
        final DateTime end = DateTime(selectedRange!.end.year, selectedRange!.end.month, selectedRange!.end.day);
        return itemDate.isBefore(start) || itemDate.isAfter(end);
      });
    }

    list.sort((a, b) =>
        sortTerbaru ? b.tglObj.compareTo(a.tglObj) : a.tglObj.compareTo(b.tglObj));

    return list;
  }

  int get totalData => filtered.length;
  int get totalHalaman => totalData == 0 ? 1 : (totalData / _barisPerHalaman).ceil();
  int get startIndex => (totalData == 0) ? 0 : (_halamanAktif - 1) * _barisPerHalaman;
  int get endIndex => min(startIndex + _barisPerHalaman, totalData);
  List<DataBatch> get dataHalamanIni {
    if (_halamanAktif > totalHalaman) _halamanAktif = totalHalaman;
    if (_halamanAktif < 1) _halamanAktif = 1;
    final s = startIndex;
    final e = endIndex;
    if (totalData == 0) return [];
    return filtered.sublist(s, e);
  }

  // ---------- detail trays ----------
  Future<List<RincianTray>> ambilDetailTrays(DataBatch batch) async {
    if (batch.detailTrays.isNotEmpty) {
      return batch.detailTrays;
    }
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
              .map((m) => RincianTray.fromMap(m))
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  // ---------- export single batch ----------
  Future<void> exportSingleBatchToExcel(DataBatch batch) async {
    final String kodeBatch = batch.batchKode;
    if (_downloadingBatches.contains(kodeBatch)) return;

    _downloadingBatches.add(kodeBatch);
    notifyListeners();

    try {
      final List<RincianTray> detailTrays = await ambilDetailTrays(batch);

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
        fileBytes = PembuatLaporanRiwayat.generateExcelBytes(params);
      } else {
        fileBytes = await compute(PembuatLaporanRiwayat.generateExcelBytes, params);
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

      onSnackbar("Berhasil mengunduh $namaFileExcel", isError: false, color: TemaRiwayat.success);
    } catch (e) {
      onSnackbar("Gagal unduh: $e", isError: true);
    } finally {
      _downloadingBatches.remove(kodeBatch);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}
