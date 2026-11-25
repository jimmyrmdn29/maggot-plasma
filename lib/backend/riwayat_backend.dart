import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as excel_pkg;

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
