import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'app_config.dart'; // ⚙️ HARI_AUTO_PANEN & ESTIMASI_RASIO_TELUR_KE_HASIL

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
