import 'package:flutter_test/flutter_test.dart';

import 'package:aplikasi_maggot/backend/panen/penyaring_panen.dart';

void main() {
  test('PenyaringPanen menyaring tray yang sudah ada di daftarNamaTray', () {
    final daftarPanen = [
      {'nama': 'Tray 1'},
      {'nama': 'Tray 2'},
    ];

    final daftarBatch = [
      {
        'daftarNamaTray': ['Tray 1'],
      },
    ];

    final hasil = PenyaringPanen.daftarAktif(
      daftarPanen: daftarPanen,
      daftarBatch: daftarBatch,
    );

    expect(hasil.length, 1);
    expect(hasil.first['nama'], 'Tray 2');
  });

  test('PenyaringPanen mempertahankan tray yang belum dibungkus', () {
    final daftarPanen = [
      {'nama': 'Tray 1'},
      {'nama': 'Tray 2'},
    ];

    final hasil = PenyaringPanen.daftarAktif(
      daftarPanen: daftarPanen,
      daftarBatch: [],
    );

    expect(hasil.length, 2);
  });

  test('PenyaringPanen menangani duplikat nama di beberapa batch', () {
    final daftarPanen = [
      {'nama': 'Tray 1'},
      {'nama': 'Tray 2'},
      {'nama': 'Tray 3'},
    ];

    final daftarBatch = [
      {
        'daftarNamaTray': ['Tray 1', 'Tray 2'],
      },
      {
        'daftarNamaTray': ['Tray 2', 'Tray 3'],
      },
    ];

    final hasil = PenyaringPanen.daftarAktif(
      daftarPanen: daftarPanen,
      daftarBatch: daftarBatch,
    );

    expect(hasil, isEmpty);
  });

  test('PenyaringPanen membaca nama dari detailTrays', () {
    final daftarPanen = [
      {'nama': 'Tray 1'},
      {'nama': 'Tray 2'},
    ];

    final daftarBatch = [
      {
        'detailTrays': [
          {'nama': 'Tray 1'},
        ],
      },
    ];

    final hasil = PenyaringPanen.daftarAktif(
      daftarPanen: daftarPanen,
      daftarBatch: daftarBatch,
    );

    expect(hasil.length, 1);
    expect(hasil.first['nama'], 'Tray 2');
  });

  test('PenyaringPanen membaca nama batch legacy', () {
    final daftarPanen = [
      {'nama': 'Tray 1'},
      {'nama': 'Tray 2'},
    ];

    final daftarBatch = [
      {'nama': 'Tray 1'},
    ];

    final hasil = PenyaringPanen.daftarAktif(
      daftarPanen: daftarPanen,
      daftarBatch: daftarBatch,
    );

    expect(hasil.length, 1);
    expect(hasil.first['nama'], 'Tray 2');
  });
}
