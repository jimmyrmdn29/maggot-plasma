// =========================================================================
// MODEL BLOK ARTIKEL
// =========================================================================
// Satu blok konten artikel: teks atau gambar (+ caption opsional).
class ArtikelBlock {
  static const String tipeTeks = 'teks';
  static const String tipeGambar = 'gambar';

  final String tipe;
  final String nilai;
  final String? caption;

  const ArtikelBlock({
    required this.tipe,
    required this.nilai,
    this.caption,
  });

  bool get isTeks => tipe == tipeTeks;
  bool get isGambar => tipe == tipeGambar;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'tipe': tipe,
      'nilai': nilai,
      if (caption != null && caption!.trim().isNotEmpty)
        'caption': caption!.trim(),
    };
  }

  factory ArtikelBlock.fromJson(Map<String, dynamic> json) {
    final String tipe = (json['tipe'] ?? tipeTeks).toString();
    final String nilai = (json['nilai'] ?? '').toString();
    final dynamic captionRaw = json['caption'];
    final String? caption = (captionRaw == null || captionRaw.toString().trim().isEmpty)
        ? null
        : captionRaw.toString().trim();

    return ArtikelBlock(
      tipe: tipe,
      nilai: nilai,
      caption: caption,
    );
  }

  static ArtikelBlock teks(String nilai) {
    return ArtikelBlock(tipe: tipeTeks, nilai: nilai);
  }

  static ArtikelBlock gambar(String url, {String? caption}) {
    return ArtikelBlock(tipe: tipeGambar, nilai: url, caption: caption);
  }
}
