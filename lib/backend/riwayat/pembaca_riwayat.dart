import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'data_batch.dart';
import 'rincian_tray.dart';

// ============================================================================
// PEMBACA RIWAYAT: DATA BATCH DARI FIRESTORE
// ============================================================================
class PembacaRiwayat {
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

  static List<DataBatch> parseFirestoreDocs(List<QueryDocumentSnapshot> docs) {
    final List<DataBatch> list = [];

    for (final doc in docs) {
      try {
        final user = doc.data() as Map<String, dynamic>? ?? {};
        list.addAll(parseSatuDokumen(doc.id, user));
      } catch (e) {
        debugPrint("Error parse doc ${doc.id}: $e");
      }
    }

    return list;
  }

  /// Parse satu dokumen user menjadi list DataBatch.
  /// Dipisah agar bisa di-unit-test tanpa Firestore (menerima Map biasa).
  static List<DataBatch> parseSatuDokumen(String docId, Map<String, dynamic> user) {
    final List<DataBatch> list = [];
    if (user['role'] == 'admin') return list;

    final String uidMitra = docId;
    final String namaMitra = user['nama']?.toString() ?? "Mitra";
    final dynamic batchRaw = user['batch'];
    if (batchRaw is! List) return list;

    for (final b in batchRaw) {
      if (b is! Map<String, dynamic>) continue;

      final bool isBatchBaru = b.containsKey('batchKode') || b.containsKey('detailTrays');

      if (isBatchBaru) {
        final tglBungkusStr = b['tanggalFormatted']?.toString() ?? "-";
        final tglObj = parseDateSuperFast(b['tanggalBungkus'] ?? tglBungkusStr);

        List<RincianTray> trays = [];
        if (b['detailTrays'] is List) {
          trays = (b['detailTrays'] as List)
              .whereType<Map<String, dynamic>>()
              .map((m) => RincianTray.fromMap(m))
              .toList();
        }

        list.add(
          DataBatch(
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
          DataBatch(
            userId: uidMitra,
            mitra: namaMitra,
            batchKode: "LEGACY-${b['nama'] ?? 'TRAY'}",
            tglBungkus: tglPanenStr,
            tglObj: tglObj,
            totalBerat: double.tryParse(b['hasilKg']?.toString() ?? '0') ?? 0.0,
            jumlahTray: 1,
            status: (b['status']?.toString() ?? "SELESAI").toUpperCase(),
            detailTrays: [RincianTray.fromMap(b)],
          ),
        );
      }
    }

    return list;
  }
}
