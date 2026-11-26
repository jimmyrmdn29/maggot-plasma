import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../app_config.dart';
import 'data_estimasi.dart';

// ============================================================================
// PEMBACA ESTIMASI: SIKLUS DARI FIRESTORE
// ============================================================================
class PembacaEstimasi {
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  static int toIntegerDate(DateTime date) {
    return date.year * 10000 + date.month * 100 + date.day;
  }

  static List<DataEstimasi> parseFirestoreDocuments(List<QueryDocumentSnapshot> docs) {
    final List<DataEstimasi> parsedList = [];

    for (final doc in docs) {
      try {
        final user = doc.data() as Map<String, dynamic>? ?? {};
        if (user['role'] == 'admin') continue;

        final dynamic siklusRaw = user['siklus'];
        if (siklusRaw is! List || siklusRaw.isEmpty) continue;

        final String namaUser = user['nama']?.toString() ?? "Mitra";

        // Ã°Å¸â€ºÂ¡Ã¯Â¸Â 1. Kumpulkan daftar tray yang sudah dipanen / ada di batch
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

        // Ã°Å¸â€ºÂ¡Ã¯Â¸Â 2. Iterasi siklus aktif
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
            DataEstimasi(
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
