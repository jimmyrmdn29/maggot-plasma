import 'package:cloudinary_public/cloudinary_public.dart';

class CloudinaryService {
  static const String _cloudName = 'lvtcqo9v';
  static const String _uploadPreset = 'preset_panen';

  final CloudinaryPublic _cloudinary = CloudinaryPublic(
    _cloudName, 
    _uploadPreset, 
    cache: false
  );

  Future<String?> uploadImage(String filePath) async {
    try {
      CloudinaryResponse res = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          filePath, 
          resourceType: CloudinaryResourceType.Image, 
          folder: 'panen_maggot'
        ),
      );
      return res.secureUrl;
    } catch (e) {
      print('Gagal upload: $e');
      return null;
    }
  }
}