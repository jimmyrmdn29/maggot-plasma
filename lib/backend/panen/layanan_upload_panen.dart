import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloudinary_public/cloudinary_public.dart';

// ============================================================================
// 1. SERVICE LAYANAN UPLOAD GAMBAR PANEN KE CLOUDINARY
// ============================================================================
class LayananUploadPanen {
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
