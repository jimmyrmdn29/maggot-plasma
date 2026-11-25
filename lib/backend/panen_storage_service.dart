import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloudinary_public/cloudinary_public.dart';

// =========================================================================
// 1. SERVICE LAYER (Menangani Upload Cloudinary secara Terisolasi & Bersih)
// =========================================================================
class CloudinaryPanenService {
  static const String cloudName = 'lvtcqo9v';
  static const String uploadPreset = 'preset_panen';
  static const String folderName = 'panen_maggot';

  final CloudinaryPublic _client = CloudinaryPublic(
    cloudName,
    uploadPreset,
    cache: false,
  );

  Future<String?> uploadFoto(String localPath) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) return null;

      final CloudinaryResponse res = await _client.uploadFile(
        CloudinaryFile.fromFile(
          localPath,
          resourceType: CloudinaryResourceType.Image,
          folder: folderName,
        ),
      );
      return res.secureUrl;
    } catch (e) {
      debugPrint("Gagal upload Cloudinary: $e");
      return null;
    }
  }
}

// =========================================================================
// 2. KONSTANTA PENYIMPANAN LOKAL
// =========================================================================
abstract class StorageKeys {
  static const String draft = 'DRAFT_PANEN_TEMPORER_MAGGOT';
  static const String queue = 'ANTREAN_SYNC_LATAR_BELAKANG_MAGGOT';
  static const String trayDibungkus = 'LIST_TRAY_SELESAI_DIBUNGKUS_MAGGOT';
}
