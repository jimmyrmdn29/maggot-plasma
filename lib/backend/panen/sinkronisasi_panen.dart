import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'layanan_upload_panen.dart';
import 'penyimpanan_panen.dart';

// ============================================================================
// 3. SERVICE LAYANAN SINKRONISASI ANTREAN PANEN (UPLOAD + UPDATE FIRESTORE)
// ============================================================================
class SinkronisasiPanen {
  static bool _sedangSyncLatarBelakang = false;

  final LayananUploadPanen _layananUpload;
  final PenyimpananPanen _penyimpanan;
  final Future<void> Function(String batchKode, List<dynamic> detailTrays) _onUpdateFotoBatch;

  SinkronisasiPanen({
    LayananUploadPanen? layananUpload,
    PenyimpananPanen? penyimpanan,
    required this._onUpdateFotoBatch,
  })  : _layananUpload = layananUpload ?? LayananUploadPanen(),
        _penyimpanan = penyimpanan ?? PenyimpananPanen();

  Future<void> jalankanProsesSync() async {
    // Anti konflik: hanya satu proses sync yang boleh berjalan bersamaan.
    if (_sedangSyncLatarBelakang) return;
    _sedangSyncLatarBelakang = true;

    try {
      final List<String> queue = await _penyimpanan.muatAntreanSync();
      if (queue.isEmpty) {
        _sedangSyncLatarBelakang = false;
        return;
      }

      final bool online = await _cekAdaInternet();
      if (!online) {
        _sedangSyncLatarBelakang = false;
        return;
      }

      final List<String> sisaQueue = [];

      for (String batchRaw in queue) {
        try {
          Map<String, dynamic> batch = jsonDecode(batchRaw);
          List<dynamic> details = batch['detailTrays'] ?? [];
          bool adaFotoGagal = false;

          // Upload menggunakan Service Cloudinary secara bertahap.
          for (var tray in details) {
            String existingUrl = tray['fotoUrl'] ?? '';
            String? localPath = tray['fotoLocalPath'];

            if (existingUrl.isEmpty && localPath != null && localPath.isNotEmpty) {
              final uploadedUrl = await _layananUpload.uploadFoto(localPath);
              if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
                tray['fotoUrl'] = uploadedUrl;
                try {
                  final f = File(localPath);
                  if (await f.exists()) await f.delete();
                } catch (_) {}
              } else {
                adaFotoGagal = true;
              }
            }
          }

          if (batch['tanggalBungkus'] is String) {
            batch['tanggalBungkus'] = Timestamp.fromDate(DateTime.parse(batch['tanggalBungkus']));
          }

          final String batchKodeSync = batch['batchKode'] ?? '';
          if (batchKodeSync.isNotEmpty) {
            await _onUpdateFotoBatch(batchKodeSync, details);
          }

          // Jika masih ada foto yang gagal karena sinyal putus,
          // pertahankan batch dengan progress terbaru di antrean.
          if (adaFotoGagal) {
            sisaQueue.add(jsonEncode(batch, toEncodable: PenyimpananPanen.customJsonSerializer));
          }
        } catch (e) {
          debugPrint("Sync tertunda: $e");
          sisaQueue.add(batchRaw);
        }
      }

      await _penyimpanan.simpanAntreanSync(sisaQueue);
    } catch (_) {
      // Gagal membaca/menyimpan antrean -> biarkan status sync bertahan untuk percobaan berikutnya.
    } finally {
      _sedangSyncLatarBelakang = false;
    }
  }

  Future<bool> _cekAdaInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
