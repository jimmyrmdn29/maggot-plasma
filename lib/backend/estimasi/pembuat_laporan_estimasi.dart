import 'dart:io';

import 'package:excel/excel.dart' as excel_pkg;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import 'data_estimasi.dart';

// ============================================================================
// PEMBUAT LAPORAN ESTIMASI: EXCEL & UNDUH
// ============================================================================
class PembuatLaporanEstimasi {
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
    required List<DataEstimasi> data,
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
// 3. BUSINESS LOGIC & PARSER LAYER
// ============================================================================
