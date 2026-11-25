import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

// =========================================================================
// HELPER: PILIH GAMBAR DARI GALERI
// =========================================================================
// Satu fungsi, satu file.
class ArtikelImagePicker {
  static final ImagePicker _picker = ImagePicker();

  static Future<Uint8List?> pickImageBytes() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return null;
    return picked.readAsBytes();
  }
}
