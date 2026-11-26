# Peta Maintain — Aplikasi Maggot

> Dokumen ini untuk maintainer: kalau bingung harus ubah file mana, mulai baca dari sini.
> Dibuat bertahap (Fase 1a–1d). Bagian yang belum ada akan ditambahkan di sub-fase berikutnya.

---

## 1. Cara menjalankan & build

**Prasyarat**
- Flutter SDK (SDK `>=3.12.0 <4.0.0`), Dart
- Firebase CLI, login sebagai `jimmyrmdn29@gmail.com`, project `maggot-plasma`
- File `.env` terisi (konfigurasi publik; tanpa service account / private key / token)

**Perintah harian**
```bash
flutter pub get
flutter run -d chrome        # web
flutter run                  # device/emulator
flutter analyze
flutter test
```

**Build**
```bash
flutter build web --release
flutter build apk --release   # Android — dilakukan manual oleh user
```

**Deploy web**
- Preview: `firebase hosting:channel:deploy preview --project maggot-plasma -e 7d`
- Production: `firebase deploy --only hosting`

**Catatan penting**
- Cloud Functions **tidak** ikut di-deploy. Auto panen jalan via `.github/workflows/auto-panen.yml`.
- `.env` sengaja di-`.gitignore` (konfigurasi publik, tapi tetap tidak dicommit).

---

## 2. Struktur folder

```
lib/
├── main.dart                          # entry point (hasil refactor A–E)
├── app.dart                           # root app
├── backend/                           # logika data + model (per fitur)
│   ├── artikel/                       # model, repository, parser, editor controller, image picker
│   ├── estimasi/                      # DataEstimasi, Pembaca, PembuatLaporan, Penyaring
│   ├── panen/                         # Penyimpanan, Sinkronisasi, LayananUpload, Kunci
│   ├── riwayat/                       # RincianTray, DataBatch, Pembaca, PembuatLaporan
│   ├── app_initializer.dart           # inisialisasi app
│   ├── auth_service.dart              # login/register/logout/mitra (target Fase 3c–3e)
│   ├── firebase_options.dart
│   └── ... (app_config, cloudinary_service, dll.)
└── frontend/                          # tampilan + alur halaman (per fitur)
    ├── artikel/                       # page_editor + widget/
    ├── auth/                          # router_pengguna
    ├── estimasi/                      # page_estimasi + tema + widget/
    ├── navigasi/                      # daftar_halaman_mitra, halaman_navigasi, item_navigasi
    ├── panen/                         # page_verifikasi_panen + widget/
    ├── riwayat/                       # page_riwayat + theme + widget/
    ├── widget/                        # komponen lintas fitur (app_header_mitra, loading_screen)
    ├── artikel/ ... , dashboard_admin_web.dart, login_page.dart, page_kelola_mitra.dart
    └── ...
```

**Aturan folder:** setiap fitur punya pasangan `lib/backend/<fitur>/` dan `lib/frontend/<fitur>/`. Tampilan kecil per komponen ada di `lib/frontend/<fitur>/widget/`. Tema/warna per fitur di `tema_<fitur>.dart` / `theme_<fitur>.dart`.

---

## 3. Daftar fitur

| Fitur | Backend | Frontend | Status struktur |
|---|---|---|---|
| Artikel (CMS) | `backend/artikel/` | `frontend/artikel/` (+ `widget/`) | Sudah dipisah |
| Estimasi panen | `backend/estimasi/` | `frontend/estimasi/` (+ `widget/`) | Sudah dipisah (Fase 5a) |
| Panen (verifikasi) | `backend/panen/` | `frontend/panen/` (+ `widget/`) | Sudah dipisah (Fase 4c) |
| Riwayat panen | `backend/riwayat/` | `frontend/riwayat/` (+ `widget/`) | Sudah dipisah (Fase 3) |
| Kelola mitra | masih di `auth_service.dart` | `frontend/page_kelola_mitra.dart` (belum dipindah) | **Target Fase 3a–3b** |
| Auth / router | `backend/auth_service.dart` | `frontend/auth/router_pengguna.dart`, `login_page.dart` | **Target Fase 3c–3e** |

## 4. Peta tanggung jawab — "kalau mau ubah X, buka file Y"

| Kalau mau mengubah… | Buka file ini | Jangan menyentuh |
|---|---|---|
| Warna / teks / tombol / ikon estimasi | `frontend/estimasi/tema_estimasi.dart`, `frontend/estimasi/widget/tampilan_*.dart` | `page_estimasi.dart`, `backend/estimasi/` |
| Warna / teks / tombol panen | `frontend/panen/widget/tampilan_*.dart`, `frontend/panen/widget/dialog_verifikasi_panen.dart` | `page_verifikasi_panen.dart`, `backend/panen/` |
| Warna / teks / tombol riwayat | `frontend/riwayat/theme_riwayat.dart`, `frontend/riwayat/widget/tampilan_*.dart` | `page_riwayat.dart`, `backend/riwayat/` |
| Urutan verifikasi panen | `frontend/panen/page_verifikasi_panen.dart` | `widget/`, `backend/panen/` |
| Filter / sort estimasi | `backend/estimasi/penyaring_estimasi.dart` | `page_estimasi.dart` |
| Format Excel estimasi | `backend/estimasi/pembuat_laporan_estimasi.dart` | `widget/` |
| Format Excel riwayat | `backend/riwayat/pembuat_laporan_riwayat.dart` | `widget/` |
| Kunci simpan draft panen (SharedPreferences) | `backend/panen/kunci_penyimpanan_panen.dart` | semua widget |
| Simpan / baca draft panen | `backend/panen/penyimpanan_panen.dart` | widget |
| Upload foto panen (Cloudinary) | `backend/panen/layanan_upload_panen.dart` | widget |
| Sinkronisasi latar belakang panen | `backend/panen/sinkronisasi_panen.dart` | widget |
| Field Firestore baru (panen/estimasi/riwayat) | model + repository fitur itu | widget (kecuali dikirim sebagai data) |
| Cara baca data mitra | `backend/auth_service.dart` (target: `backend/mitra/penyimpanan_mitra.dart`) | widget kelola mitra |
| Blok / parser artikel | `backend/artikel/artikel_block.dart`, `artikel_parser.dart` | `page_editor_artikel.dart` |
| Navigasi halaman mitra | `frontend/navigasi/daftar_halaman_mitra.dart`, `halaman_navigasi.dart` | — |
| Loading awal app | `frontend/widget/loading_screen.dart`, `backend/app_initializer.dart` | — |
| Header mitra | `frontend/widget/app_header_mitra.dart` | — |

**Tiga lapisan (pola Fase 4c)** — pegangan kalau bingung:
- **Alur** (urutan langkah) → `frontend/<fitur>/page_*.dart`
- **Data** (baca/tulis Firestore/SharedPreferences/Cloudinary) → `backend/<fitur>/`
- **Tampilan** (widget, hanya terima data + callback) → `frontend/<fitur>/widget/`

---

## 5. Decision tree — "kode ini seharusnya hidup di mana?"

Tanya 3 pertanyaan sebelum mengedit:

1. **Kalau desain UI diganti, kode ini ikut berubah?** → `frontend/<fitur>/widget/` + `tema_*.dart`
2. **Kalau cara simpan/ambil data diganti, kode ini ikut berubah?** → `backend/<fitur>/`
3. **Kalau urutan/langkah diubah, kode ini yang berubah?** → `frontend/<fitur>/page_*.dart`

Kalau jawabannya **dua atau tiga "ya" sekaligus**, berhenti dulu — itu tanda kode itu masih campur tanggung jawab, dan memaksanya masuk ke salah satu folder akan bikin pusing lagi.

## 6. Checklist tambah fitur (biar nyambung & nggak merusak)

Tiap fitur baru, jalankan urutan ini:

1. Tulis dulu satu kalimat: **"fitur ini baca/tulis data apa?"** (Firestore? SharedPreferences? Cloudinary? tidak ada?)
2. Model dulu di `backend/<fitur>/` (pure Dart, tanpa Flutter)
3. Repository / service di `backend/<fitur>/` kalau ada data
4. Alur / state di `frontend/<fitur>/page_*.dart`
5. Tampilan di `frontend/<fitur>/widget/` — terima data + callback, **jangan** panggil repository
6. Daftarkan di navigasi kalau ada halaman baru (`frontend/navigasi/daftar_halaman_mitra.dart`)
7. Unit test untuk logika murni (filter, parsing, urutan)
8. `flutter analyze` + `flutter test` + cek preview web

**Aturan emas:** kalau kamu mendapati diri mengedit tiga lapis sekaligus untuk satu permintaan kecil, itu sinyal fitur itu belum punya "rumah" yang jelas — bukan berarti kamu harus buru-buru bikin file baru. Berhenti, pecah tanggung jawabnya dulu.

### Contoh nyata: tambah tombol "Unduh PDF" di halaman estimasi

- Data: tidak ada field baru → **backend tidak disentuh**
- Flow: tambah `_exportToPdf` + state `_isExportingPdf` di `page_estimasi.dart`
- Service: `PembuatLaporanEstimasi.exportPdf(...)` di `backend/estimasi/`
- Tampilan: tombol di `frontend/estimasi/widget/tampilan_footer_estimasi.dart`, warna di `tema_estimasi.dart`
- Navigasi: tidak berubah
- Test: unit test untuk format nama file
- Cek: `flutter analyze` + `flutter test` + preview

Empat file, semua masih satu fitur, **nol perubahan di fitur lain**. Itu yang dimaksud "nyambung tanpa merusak".

## 7. Cek sebelum deploy

Jalankan berurutan, jangan skip:

1. `flutter analyze` → **0 error, 0 warning** (info boleh)
2. `flutter test` → **All tests passed!**
3. `flutter build web --release` → build sukses
4. `flutter build apk --release` → build sukses (kalau deploy Android)
5. Cek preview web dulu, baru production:
   - Preview: `firebase hosting:channel:deploy preview --project maggot-plasma -e 7d`
   - Production: `firebase deploy --only hosting`
6. `git status` → pastikan `.env`, `*.jks`, `*firebase-adminsdk-*.json`, `serviceAccountKey.json` **tidak** ikut commit
7. Pastikan `firestore.rules` di console sesuai aturan artikel: authenticated boleh baca; hanya `role == 'admin'` yang boleh tulis
8. Pastikan `.env` format `KEY=value`, preset `preset_panen`, folder Cloudinary `artikel_maggot` (artikel) / `panen_maggot` (panen)

---

## 8. Utang teknis (belum selesai)

| # | Utang | Dampak | Target fase |
|---|---|---|---|
| 1 | Queue `akun_auth_perlu_dihapus` belum punya worker → akun Firebase Auth bisa jadi yatim saat mitra dihapus | Akun Auth menumpuk | Fase 5b |
| 2 | `firebase.json` masih menunjuk `lib/firebase_options.dart`, file aktual di `lib/backend/firebase_options.dart` | Potensi build/deploy gagal | Fase 5c |
| 3 | `firestore.rules` belum tersimpan di repo / `firebase.json` (aturan artikel diterapkan manual di console) | Aturan tidak ter-version-control | Fase 5c |
| 4 | `page_kelola_mitra.dart` & `auth_service.dart` belum dipindah ke struktur fitur | Backend flat, frontend campur | Fase 3 |
| 5 | Viewmodel masih menempel di `State<Page...>` | Sulit di-test, state ikut rebuild | Fase 4 |
| 6 | Test hanya 1 (cek konfigurasi) | Refactor tidak bisa diverifikasi perilakunya | Fase 2 |
| 7 | Deploy channel preview: `--only hosting` pada channel deploy gagal (`Hosting site or target hosting not detected in firebase.json`) | Preview harus tanpa `--only` | — |

---

> **Fase 1 (Peta Maintain) selesai.** Bagian 1–8 lengkap. Sub-fase berikutnya: **Fase 2 (jaring pengaman test)**.
