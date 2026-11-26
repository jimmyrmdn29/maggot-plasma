import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aplikasi_maggot/backend/estimasi/pembaca_estimasi.dart';

void main() {
  group('PembacaEstimasi.toIntegerDate', () {
    test('format YYYYMMDD tanpa padding manual', () {
      expect(PembacaEstimasi.toIntegerDate(DateTime(2026, 1, 5)), 20260105);
      expect(PembacaEstimasi.toIntegerDate(DateTime(2026, 12, 31)), 20261231);
      expect(PembacaEstimasi.toIntegerDate(DateTime(2025, 6, 15)), 20250615);
    });
  });

  group('PembacaEstimasi.parseSatuDokumen', () {
    test('role admin → list kosong', () {
      final hasil = PembacaEstimasi.parseSatuDokumen('doc1', {
        'role': 'admin',
        'siklus': [
          {'nama': 'TRAY-01', 'tanggalMulai': DateTime(2026, 1, 1), 'beratTelur': 100},
        ],
      });
      expect(hasil, isEmpty);
    });

    test('siklus null / kosong / bukan list → list kosong', () {
      expect(PembacaEstimasi.parseSatuDokumen('d', {'nama': 'Mitra'}), isEmpty);
      expect(PembacaEstimasi.parseSatuDokumen('d', {'nama': 'Mitra', 'siklus': []}), isEmpty);
      expect(PembacaEstimasi.parseSatuDokumen('d', {'nama': 'Mitra', 'siklus': 'bukan list'}), isEmpty);
    });

    test('siklus aktif → 1 DataEstimasi dengan field benar', () {
      final tglMulai = DateTime(2026, 1, 1);
      final hasil = PembacaEstimasi.parseSatuDokumen('d', {
        'nama': 'Budi',
        'siklus': [
          {'nama': 'TRAY-01', 'tanggalMulai': tglMulai, 'beratTelur': 100},
        ],
      });

      expect(hasil.length, 1);
      final e = hasil.first;
      expect(e.nama, 'Budi');
      expect(e.tray, 'TRAY-01');
      expect(e.telur, 100.0);
      expect(e.estimasiKg, 200.0); // 100 * 2.0
      expect(e.tglMulaiStr, '01/01/2026');
      expect(e.tglObj, tglMulai.add(const Duration(days: 21)));
      expect(e.dateKey, PembacaEstimasi.toIntegerDate(tglMulai.add(const Duration(days: 21))));
    });

    test('tray yang sudah dipanen (detailTrays batch) → di-skip', () {
      final hasil = PembacaEstimasi.parseSatuDokumen('d', {
        'nama': 'Budi',
        'batch': [
          {
            'detailTrays': [
              {'nama': 'TRAY-01'},
            ],
          },
        ],
        'siklus': [
          {'nama': 'TRAY-01', 'tanggalMulai': DateTime(2026, 1, 1), 'beratTelur': 100},
        ],
      });
      expect(hasil, isEmpty);
    });

    test('tray yang sudah dipanen (nama batch) → di-skip', () {
      final hasil = PembacaEstimasi.parseSatuDokumen('d', {
        'nama': 'Budi',
        'batch': [
          {'nama': 'TRAY-01'},
        ],
        'siklus': [
          {'nama': 'TRAY-01', 'tanggalMulai': DateTime(2026, 1, 1), 'beratTelur': 100},
        ],
      });
      expect(hasil, isEmpty);
    });

    test('status selesai / panen / isPanen true → di-skip', () {
      for (final status in ['selesai', 'panen']) {
        final hasil = PembacaEstimasi.parseSatuDokumen('d', {
          'nama': 'Budi',
          'siklus': [
            {'nama': 'TRAY-$status', 'tanggalMulai': DateTime(2026, 1, 1), 'beratTelur': 100, 'status': status},
          ],
        });
        expect(hasil, isEmpty, reason: 'status=$status');
      }
      final hasil2 = PembacaEstimasi.parseSatuDokumen('d', {
        'nama': 'Budi',
        'siklus': [
          {'nama': 'TRAY-X', 'tanggalMulai': DateTime(2026, 1, 1), 'beratTelur': 100, 'isPanen': true},
        ],
      });
      expect(hasil2, isEmpty);
    });

    test('tanggalMulai null → siklus itu di-skip, yang lain tetap', () {
      final hasil = PembacaEstimasi.parseSatuDokumen('d', {
        'nama': 'Budi',
        'siklus': [
          {'nama': 'TRAY-NULL', 'tanggalMulai': null, 'beratTelur': 100},
          {'nama': 'TRAY-OK', 'tanggalMulai': DateTime(2026, 1, 1), 'beratTelur': 50},
        ],
      });
      expect(hasil.length, 1);
      expect(hasil.first.tray, 'TRAY-OK');
    });

    test('tanggalMulai Timestamp → toDate() dipakai', () {
      final ts = Timestamp.fromDate(DateTime(2026, 2, 2));
      final hasil = PembacaEstimasi.parseSatuDokumen('d', {
        'nama': 'Budi',
        'siklus': [
          {'nama': 'TRAY-TS', 'tanggalMulai': ts, 'beratTelur': 10},
        ],
      });
      expect(hasil.length, 1);
      expect(hasil.first.tglMulaiStr, '02/02/2026');
    });

    test('tanggalMulai String ISO → di-parse', () {
      final hasil = PembacaEstimasi.parseSatuDokumen('d', {
        'nama': 'Budi',
        'siklus': [
          {'nama': 'TRAY-STR', 'tanggalMulai': '2026-03-03T00:00:00.000', 'beratTelur': 10},
        ],
      });
      expect(hasil.length, 1);
      expect(hasil.first.tglMulaiStr, '03/03/2026');
    });

    test('beratTelur string / kosong → di-parse aman', () {
      final hasil = PembacaEstimasi.parseSatuDokumen('d', {
        'nama': 'Budi',
        'siklus': [
          {'nama': 'TRAY-A', 'tanggalMulai': DateTime(2026, 1, 1), 'beratTelur': 'abc'},
          {'nama': 'TRAY-B', 'tanggalMulai': DateTime(2026, 1, 1), 'beratTelur': 25},
        ],
      });
      expect(hasil.length, 2);
      expect(hasil[0].telur, 0.0);
      expect(hasil[1].telur, 25.0);
    });

    test('siklus bukan Map → di-skip', () {
      final hasil = PembacaEstimasi.parseSatuDokumen('d', {
        'nama': 'Budi',
        'siklus': ['bukan map', 123],
      });
      expect(hasil, isEmpty);
    });

    test('nama user fallback "Mitra" kalau tidak ada', () {
      final hasil = PembacaEstimasi.parseSatuDokumen('d', {
        'siklus': [
          {'nama': 'TRAY-X', 'tanggalMulai': DateTime(2026, 1, 1), 'beratTelur': 1},
        ],
      });
      expect(hasil.first.nama, 'Mitra');
    });

    test('nama tray fallback "-" kalau tidak ada', () {
      final hasil = PembacaEstimasi.parseSatuDokumen('d', {
        'nama': 'Budi',
        'siklus': [
          {'tanggalMulai': DateTime(2026, 1, 1), 'beratTelur': 1},
        ],
      });
      expect(hasil.first.tray, '-');
    });
  });
}
