import 'dart:typed_data';

import 'package:cloudinary_public/cloudinary_public.dart';

class CloudinaryService {
  static const String _cloudName = 'lvtcqo9v';
  static const String _uploadPreset = 'preset_panen';

  final CloudinaryPublic _cloudinary = CloudinaryPublic(
    _cloudName, 
    _uploadPreset, 
    cache: false
  );

  // folder default dipertahankan agar pemanggil lama (panen) tidak berubah.
  Future<String?> uploadImage(String filePath, {String folder = 'panen_maggot'}) async {
    try {
      CloudinaryResponse res = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          filePath, 
          resourceType: CloudinaryResourceType.Image, 
          folder: folder,
        ),
      );
      return res.secureUrl;
    } catch (e) {
      print('Gagal upload: $e');
      return null;
    }
  }

  // Upload dari bytes (aman untuk web & mobile).
  Future<String?> uploadImageBytes(Uint8List bytes, {String folder = 'artikel_maggot'}) async {
    try {
      final CloudinaryFile file = CloudinaryFile.fromBytesData(
        bytes,
        identifier: 'artikel_${DateTime.now().millisecondsSinceEpoch}.jpg',
        resourceType: CloudinaryResourceType.Image,
        folder: folder,
      );
      final CloudinaryResponse res = await _cloudinary.uploadFile(file);
      return res.secureUrl;
    } catch (e) {
      print('Gagal upload bytes: $e');
      return null;
    }
  }
}