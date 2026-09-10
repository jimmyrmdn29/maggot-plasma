// ═══════════════════════════════════════════════════════════════════════════
// 🎛️  KONFIGURASI UTAMA APLIKASI MAGFEED  —  MUDAH DIEDIT
//    Ubah nilai-nilai di bawah sesuai kebutuhan. TIDAK PERLU edit file lain.
//    Lokasi file ini: lib/app_config.dart
// ═══════════════════════════════════════════════════════════════════════════


// ───────────────────────────────────────────────────────────────────────────
// [1] COUNTER TRAY: BERAPA BULAN SEKALI DIRESET KE #1 LAGI?
// ───────────────────────────────────────────────────────────────────────────
// Contoh:
//   1 = Reset SETIAP BULAN (Jan, Feb, Mar, ...)  ← DEFAULT
//   2 = Reset tiap 2 BULAN (Januari → Maret → Mei, dst)
//   3 = Reset tiap 3 BULAN (triwulan)
//   6 = Reset tiap 6 BULAN (semester)
//   0 = JANGAN PERNAH direset otomatis (counter terus naik tanpa batas)

//const int resetCounterTraySetiapNBulan = 1;

// ───────────────────────────────────────────────────────────────────────────
// [2] HARI KE BERAPA SIKLUS MAGGOT OTOMATIS SIAP PANEN?
// ───────────────────────────────────────────────────────────────────────────
// Standar budidaya maggot: 21 hari (3 minggu)

const int HARI_AUTO_PANEN = 21;

// ───────────────────────────────────────────────────────────────────────────
// [3] ESTIMASI RASIO KONVERSI TELUR → HASIL PANEN (Kg)
// ───────────────────────────────────────────────────────────────────────────
// Digunakan di halaman Estimasi Stok (Admin).
// Rumus: Berat Telur (gram) × RASIO  =  Estimasi Hasil Panen (Kg)
// Contoh: 500 gram telur × 2.0 = 1.0 Kg estimasi hasil panen

const double ESTIMASI_RASIO_TELUR_KE_HASIL = 2.0;

// ───────────────────────────────────────────────────────────────────────────
// [4] KUALITAS FOTO BUKTI PANEN (1 - 100, MAKIN BESAR MAKIN JELAS TAPI BERAT)
// ───────────────────────────────────────────────────────────────────────────
// Disarankan 30 - 50. Lebih dari 60 bisa bikin dokumen Firestore besar
// dan melambatkan loading data mitra.

const int KUALITAS_FOTO_BUKTI = 70;

