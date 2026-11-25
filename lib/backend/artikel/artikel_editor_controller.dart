import 'package:flutter/foundation.dart';

import 'artikel_block.dart';
import 'artikel_repository.dart';
import '../cloudinary_service.dart';

// =========================================================================
// CONTROLLER / LOGIKA FITUR EDITOR ARTIKEL
// =========================================================================
// File ini hanya logika + state. Tidak ada widget Flutter di sini.
class ArtikelEditorController extends ChangeNotifier {
  ArtikelEditorController({
    this.artikelId,
    String? judulAwal,
    String? coverAwal,
    List<ArtikelBlock>? kontenAwal,
  })  : _judul = judulAwal ?? '',
        _coverUrl = (coverAwal == null || coverAwal.trim().isEmpty)
            ? null
            : coverAwal.trim(),
        _blocks = List<ArtikelBlock>.from(kontenAwal ?? const <ArtikelBlock>[]);

  final String? artikelId;

  String _judul;
  String? _coverUrl;
  List<ArtikelBlock> _blocks;
  bool _isSaving = false;
  bool _isUploading = false;

  String get judul => _judul;
  String? get coverUrl => _coverUrl;
  List<ArtikelBlock> get blocks => List<ArtikelBlock>.unmodifiable(_blocks);
  bool get isSaving => _isSaving;
  bool get isUploading => _isUploading;
  bool get sedangSibuk => _isSaving || _isUploading;

  void setJudul(String value) {
    _judul = value;
    notifyListeners();
  }

  void hapusCover() {
    _coverUrl = null;
    notifyListeners();
  }

  Future<bool> uploadCover(Uint8List bytes) async {
    _isUploading = true;
    notifyListeners();

    final String? url = await CloudinaryService().uploadImageBytes(
      bytes,
      folder: 'artikel_maggot',
    );

    _isUploading = false;
    if (url != null) {
      _coverUrl = url;
    }
    notifyListeners();
    return url != null;
  }

  void tambahTeks({String nilai = ''}) {
    _blocks = List<ArtikelBlock>.from(_blocks)
      ..add(ArtikelBlock.teks(nilai));
    notifyListeners();
  }

  void ubahTeks(int index, String nilai) {
    if (index < 0 || index >= _blocks.length) return;
    if (!_blocks[index].isTeks) return;
    final List<ArtikelBlock> baru = List<ArtikelBlock>.from(_blocks);
    baru[index] = ArtikelBlock.teks(nilai);
    _blocks = baru;
    notifyListeners();
  }

  Future<bool> tambahGambar(Uint8List bytes, {String? caption}) async {
    _isUploading = true;
    notifyListeners();

    final String? url = await CloudinaryService().uploadImageBytes(
      bytes,
      folder: 'artikel_maggot',
    );

    _isUploading = false;
    if (url != null) {
      _blocks = List<ArtikelBlock>.from(_blocks)
        ..add(ArtikelBlock.gambar(url, caption: caption));
    }
    notifyListeners();
    return url != null;
  }

  void ubahCaptionGambar(int index, String caption) {
    if (index < 0 || index >= _blocks.length) return;
    final ArtikelBlock block = _blocks[index];
    if (!block.isGambar) return;
    final List<ArtikelBlock> baru = List<ArtikelBlock>.from(_blocks);
    baru[index] = ArtikelBlock.gambar(block.nilai, caption: caption);
    _blocks = baru;
    notifyListeners();
  }

  void hapusBlock(int index) {
    if (index < 0 || index >= _blocks.length) return;
    final List<ArtikelBlock> baru = List<ArtikelBlock>.from(_blocks)..removeAt(index);
    _blocks = baru;
    notifyListeners();
  }

  void pindahAtas(int index) {
    if (index <= 0 || index >= _blocks.length) return;
    final List<ArtikelBlock> baru = List<ArtikelBlock>.from(_blocks);
    final ArtikelBlock tmp = baru[index - 1];
    baru[index - 1] = baru[index];
    baru[index] = tmp;
    _blocks = baru;
    notifyListeners();
  }

  void pindahBawah(int index) {
    if (index < 0 || index >= _blocks.length - 1) return;
    final List<ArtikelBlock> baru = List<ArtikelBlock>.from(_blocks);
    final ArtikelBlock tmp = baru[index + 1];
    baru[index + 1] = baru[index];
    baru[index] = tmp;
    _blocks = baru;
    notifyListeners();
  }

  Future<bool> simpan(String uid) async {
    if (_judul.trim().isEmpty) return false;
    if (sedangSibuk) return false;

    _isSaving = true;
    notifyListeners();

    try {
      await ArtikelRepository.simpanArtikel(
        uid: uid,
        judul: _judul,
        konten: _blocks,
        gambarUrl: _coverUrl,
        id: artikelId,
      );
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (_) {
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }
}
