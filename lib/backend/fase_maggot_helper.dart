// =========================================================================
// HELPER FASE MAGGOT (Memisahkan Logika Gambar & Umur dari UI)
// =========================================================================
class FaseMaggotHelper {
  final String label;
  final String pathGambar;

  const FaseMaggotHelper({required this.label, required this.pathGambar});

  factory FaseMaggotHelper.dariUmur(int hari) {
    if (hari <= 5) {
      return const FaseMaggotHelper(
        label: "TELUR",
        pathGambar: "assets/images/telur.png",
      );
    } else if (hari <= 13) {
      return const FaseMaggotHelper(
        label: "BABY",
        pathGambar: "assets/images/baby_maggot.png",
      );
    } else {
      return const FaseMaggotHelper(
        label: "MAGGOT LAPAR",
        pathGambar: "assets/images/maggot_lapar.png",
      );
    }
  }
}
