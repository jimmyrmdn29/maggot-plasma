// ═══════════════════════════════════════════════════════════════════════════
// 🎛️  KONFIGURASI UTAMA APLIKASI —  MUDAH DIEDIT
//    Ubah nilai-nilai di bawah sesuai kebutuhan. TIDAK PERLU edit file lain.
//    Lokasi file ini: lib/app_config.dart
// ═══════════════════════════════════════════════════════════════════════════


// ───────────────────────────────────────────────────────────────────────────
// [1] HARI KE BERAPA SIKLUS MAGGOT OTOMATIS SIAP PANEN?
// ───────────────────────────────────────────────────────────────────────────
// Standar budidaya maggot: 21 hari (3 minggu)

const int HARI_AUTO_PANEN = 21;

// ───────────────────────────────────────────────────────────────────────────
// [2] ESTIMASI RASIO KONVERSI TELUR → HASIL PANEN (Kg)
// ───────────────────────────────────────────────────────────────────────────
// Digunakan di halaman Estimasi Stok (Admin).
 // Formula: Berat Telur (Gram) × Rasio = Estimasi Hasil Panen Maggot Basah (Kg)
  // Nilai Default: 2.0 (Artinya 1 gram telur diasumsikan menghasilkan 2 Kg maggot).
  //
  // CATATAN KEPUTUSAN BISNIS (BUSINESS RISK MITIGATION):
  // Secara teori ideal, 1 gr telur bisa menghasilkan 3 - 4 Kg maggot. Namun,
  // rasio ini sengaja diset secara KONSERVATIF pada angka aman 2.0 (~60-70% potensi riil)
  // guna mengantisipasi faktor mortalitas di kandang mitra dan fluktuasi pakan.
  //
  // Manfaat Strategis:
  // 1. Menjamin perusahaan selalu SURPLUS dan tidak wanprestasi dalam kontrak suplai.
  // 2. Mencegah over-forecasting pada perencanaan kapasitas gudang & penjualan.

const double ESTIMASI_RASIO_TELUR_KE_HASIL = 2.0;

// ───────────────────────────────────────────────────────────────────────────
// [3] KUALITAS FOTO BUKTI PANEN (1 - 100, MAKIN BESAR MAKIN JELAS TAPI BERAT)
// ───────────────────────────────────────────────────────────────────────────
// Disarankan 30 - 50. Lebih dari 60 bisa bikin dokumen Firestore besar
// dan melambatkan loading data mitra.

const int KUALITAS_FOTO_BUKTI = 70;

