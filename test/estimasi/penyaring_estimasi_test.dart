import 'package:flutter_test/flutter_test.dart';
import 'package:aplikasi_maggot/backend/estimasi/data_estimasi.dart';
import 'package:aplikasi_maggot/backend/estimasi/penyaring_estimasi.dart';

DataEstimasi buat({
  required String nama,
  required String tray,
  int dateKey = 20260101,
}) {
  return DataEstimasi(
    nama: nama,
    tray: tray,
    telur: 100.0,
    tglMulaiStr: '01/01/2026',
    tglObj: DateTime(2026, 1, 1),
    dateKey: dateKey,
    tglEstimasiStr: '10/01/2026',
    estimasiKg: 5.0,
  );
}

void main() {
  group('PenyaringEstimasi.terapkanFilter', () {
    final data = [
      buat(nama: 'Budi', tray: 'TRAY-01', dateKey: 20260101),
      buat(nama: 'Ani', tray: 'TRAY-02', dateKey: 20260105),
      buat(nama: 'Caca', tray: 'TRAY-03', dateKey: 20260110),
    ];

    test('data kosong menghasilkan list kosong', () {
      expect(PenyaringEstimasi.terapkanFilter(data: []), isEmpty);
    });

    test('cariMitra null/whitespace mengembalikan semua data', () {
      expect(PenyaringEstimasi.terapkanFilter(data: data, cariMitra: null).length, 3);
      expect(PenyaringEstimasi.terapkanFilter(data: data, cariMitra: '   ').length, 3);
    });

    test('filter teks case-insensitive pada nama/tray', () {
      final hasil = PenyaringEstimasi.terapkanFilter(data: data, cariMitra: 'budi');
      expect(hasil.length, 1);
      expect(hasil.first.nama, 'Budi');

      final hasil2 = PenyaringEstimasi.terapkanFilter(data: data, cariMitra: 'TRAY-02');
      expect(hasil2.length, 1);
      expect(hasil2.first.nama, 'Ani');
    });

    test('filter teks yang tidak cocok menghasilkan kosong', () {
      final hasil = PenyaringEstimasi.terapkanFilter(data: data, cariMitra: 'zzz');
      expect(hasil, isEmpty);
    });

    test('filter rentang tanggal inklusif', () {
      final hasil = PenyaringEstimasi.terapkanFilter(
        data: data,
        startDateKey: 20260105,
        endDateKey: 20260110,
      );
      expect(hasil.length, 2);
      expect(hasil.map((e) => e.nama), containsAll(['Ani', 'Caca']));
    });

    test('filter rentang hanya diterapkan kalau kedua kunci ada', () {
      // hanya startDateKey, tanpa endDateKey → tidak filter tanggal
      final hasil = PenyaringEstimasi.terapkanFilter(
        data: data,
        startDateKey: 20260105,
      );
      expect(hasil.length, 3);
    });

    test('filter teks + rentang tanggal digabung (AND)', () {
      final hasil = PenyaringEstimasi.terapkanFilter(
        data: data,
        cariMitra: 'tray',
        startDateKey: 20260105,
        endDateKey: 20260110,
      );
      expect(hasil.length, 2);
      expect(hasil.map((e) => e.nama), containsAll(['Ani', 'Caca']));
    });
  });

  group('PenyaringEstimasi.mengurutkan', () {
    final data = [
      buat(nama: 'A', tray: 'T1', dateKey: 20260101),
      buat(nama: 'B', tray: 'T2', dateKey: 20260105),
      buat(nama: 'C', tray: 'T3', dateKey: 20260110),
    ];

    test('sortTerbaru true → descending berdasarkan dateKey', () {
      final hasil = PenyaringEstimasi.mengurutkan(data: data, sortTerbaru: true);
      expect(hasil.map((e) => e.dateKey).toList(), [20260110, 20260105, 20260101]);
    });

    test('sortTerbaru false → ascending berdasarkan dateKey', () {
      final hasil = PenyaringEstimasi.mengurutkan(data: data, sortTerbaru: false);
      expect(hasil.map((e) => e.dateKey).toList(), [20260101, 20260105, 20260110]);
    });

    test('tidak memutasi list input', () {
      final asli = List<DataEstimasi>.from(data);
      PenyaringEstimasi.mengurutkan(data: data, sortTerbaru: true);
      expect(data.map((e) => e.dateKey).toList(), asli.map((e) => e.dateKey).toList());
    });

    test('list kosong tetap kosong', () {
      expect(PenyaringEstimasi.mengurutkan(data: [], sortTerbaru: true), isEmpty);
    });
  });
}
