import 'package:excel/excel.dart' as excel_pkg;
import 'package:flutter/foundation.dart';

// ============================================================================
// PEMBUAT LAPORAN RIWAYAT: EXCEL PER BATCH
// ============================================================================
class PembuatLaporanRiwayat {
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
