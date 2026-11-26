import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../backend/maggot_repository.dart';
import '../../backend/panen/penyaring_panen.dart';
import '../menu1.dart';
import '../menu2.dart';
import '../panen/page_verifikasi_panen.dart';
import '../menu4.dart';
import '../page_artikel.dart';

// =========================================================================
// DAFTAR HALAMAN MITRA
// =========================================================================
// Satu tanggung jawab: susun halaman mitra dan sambungkan ke repository.
List<Widget> buatHalamanMitra({
  required User user,
  required Map<String, dynamic> userData,
}) {
  final List<Map<String, dynamic>> dbSiklus =
      List<Map<String, dynamic>>.from(userData['siklus'] ?? []);
  final List<Map<String, dynamic>> dbPanen =
      List<Map<String, dynamic>>.from(userData['panen'] ?? []);
  final List<Map<String, dynamic>> dbBatch =
      List<Map<String, dynamic>>.from(userData['batch'] ?? []);

  // Tray yang sudah pernah dibungkus tidak boleh muncul lagi di Menu 3.
  final List<Map<String, dynamic>> dbPanenAktif = PenyaringPanen.daftarAktif(
    daftarPanen: dbPanen,
    daftarBatch: dbBatch,
  );

  return <Widget>[
    MenuSatu(
      nomorTrayOtomatis: userData['counterTray'] ?? 1,
      namaMitra: userData['nama'] ?? 'Mitra',
      onTambahBanyakData: (daftarTray) => MaggotRepository.tambahBanyakTray(
        uid: user.uid,
        namaMitra: userData['nama'] ?? 'Mitra',
        counterAwal: userData['counterTray'] ?? 1,
        daftarTrayBaru: daftarTray,
        dbSiklusLama: dbSiklus,
      ),
    ),
    MenuDua(
      daftarSiklus: dbSiklus,
      onKonfirmasiSehat: (index, minggu) => MaggotRepository.konfirmasiSehat(
        uid: user.uid,
        dbSiklus: dbSiklus,
        index: index,
        minggu: minggu,
      ),
      onPanenOtomatis: (index, dataPanen) => MaggotRepository.pindahkanKePanen(
        uid: user.uid,
        dbSiklus: dbSiklus,
        dbPanen: dbPanen,
        index: index,
        dataBaru: dataPanen,
      ),
      onGagalKePanen: (index, dataGagal) => MaggotRepository.pindahkanKePanen(
        uid: user.uid,
        dbSiklus: dbSiklus,
        dbPanen: dbPanen,
        index: index,
        dataBaru: dataGagal,
      ),
    ),
    PageVerifikasiPanen(
      daftarPanen: dbPanenAktif,
      onBungkusBatch: (paketBatch) => MaggotRepository.bungkusBatch(
        uid: user.uid,
        paketBatch: paketBatch,
        dbPanenLama: dbPanenAktif,
      ),
      onUpdateFotoBatch: (batchKode, detailTrays) => MaggotRepository.updateFotoBatch(
        uid: user.uid,
        batchKode: batchKode,
        detailTraysTerbaru: detailTrays,
      ),
    ),
    MenuEmpat(
      daftarBatch: dbBatch,
      onHapusBatchManual: (index) => MaggotRepository.hapusBatchManual(
        uid: user.uid,
        dbBatch: dbBatch,
        index: index,
      ),
    ),
    const PageArtikel(),
  ];
}