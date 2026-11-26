import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aplikasi_maggot/backend/riwayat/pembaca_riwayat.dart';

void main() {
  group('PembacaRiwayat.parseDateSuperFast', () {
    test('null / "-" / kosong → epoch 1970', () {
      expect(PembacaRiwayat.parseDateSuperFast(null), DateTime(1970));
      expect(PembacaRiwayat.parseDateSuperFast('-'), DateTime(1970));
      expect(PembacaRiwayat.parseDateSuperFast(''), DateTime(1970));
    });

    test('Timestamp → toDate()', () {
      final ts = Timestamp.fromDate(DateTime(2026, 5, 5, 10, 30, 0));
      expect(PembacaRiwayat.parseDateSuperFast(ts), DateTime(2026, 5, 5, 10, 30, 0));
    });

    test('DateTime → langsung', () {
      final dt = DateTime(2026, 5, 5);
      expect(PembacaRiwayat.parseDateSuperFast(dt), dt);
    });

    test('format ISO (p0 > 1000) → DateTime(p0,p1,p2)', () {
      expect(PembacaRiwayat.parseDateSuperFast('2026-05-05'), DateTime(2026, 5, 5));
      expect(PembacaRiwayat.parseDateSuperFast('2026/05/05 10:30:00'), DateTime(2026, 5, 5, 10, 30, 0));
    });

    test('format dd/MM/yyyy (p2 > 1000) → DateTime(p2,p1,p0)', () {
      expect(PembacaRiwayat.parseDateSuperFast('05/05/2026'), DateTime(2026, 5, 5));
      expect(PembacaRiwayat.parseDateSuperFast('05-05-2026'), DateTime(2026, 5, 5));
    });

    test('string tidak bisa diparse → DateTime.tryParse atau 1970', () {
      final hasil = PembacaRiwayat.parseDateSuperFast('bukan tanggal');
      expect(hasil, DateTime(1970));
    });
  });

  group('PembacaRiwayat.safeDecodeBase64', () {
    test('null / kosong → null', () {
      expect(PembacaRiwayat.safeDecodeBase64(null), isNull);
      expect(PembacaRiwayat.safeDecodeBase64(''), isNull);
      expect(PembacaRiwayat.safeDecodeBase64('   '), isNull);
    });

    test('base64 valid → bytes', () {
      final encoded = base64Encode([1, 2, 3]);
      final decoded = PembacaRiwayat.safeDecodeBase64(encoded);
      expect(decoded, isNotNull);
      expect(decoded!.toList(), [1, 2, 3]);
    });

    test('data URL prefix → di-strip', () {
      final encoded = base64Encode([7, 8]);
      final decoded = PembacaRiwayat.safeDecodeBase64('data:image/png;base64,$encoded');
      expect(decoded, isNotNull);
      expect(decoded!.toList(), [7, 8]);
    });

    test('base64 invalid → null (tidak throw)', () {
      expect(PembacaRiwayat.safeDecodeBase64('!!!not base64!!!'), isNull);
    });
  });

  group('PembacaRiwayat.parseSatuDokumen', () {
    test('role admin → list kosong', () {
      final hasil = PembacaRiwayat.parseSatuDokumen('uid1', {
        'role': 'admin',
        'batch': [
          {'batchKode': 'B1', 'tanggalFormatted': '01/01/2026'},
        ],
      });
      expect(hasil, isEmpty);
    });

    test('batch bukan list → list kosong', () {
      final hasil = PembacaRiwayat.parseSatuDokumen('uid1', {
        'nama': 'Mitra',
        'batch': 'bukan list',
      });
      expect(hasil, isEmpty);
    });

    test('batch baru (ada batchKode) → DataBatch dengan field benar', () {
      final hasil = PembacaRiwayat.parseSatuDokumen('uid1', {
        'nama': 'Budi',
        'batch': [
          {
            'batchKode': 'BATCH-001',
            'tanggalFormatted': '01/01/2026',
            'tanggalBungkus': '2026-01-01',
            'totalBeratKg': '10.5',
            'jumlahTray': 3,
            'status': 'terbungkus',
            'detailTrays': [
              {'nama': 'TRAY-01', 'hasilKg': '3.5', 'status': 'BERHASIL'},
            ],
          },
        ],
      });

      expect(hasil.length, 1);
      final b = hasil.first;
      expect(b.userId, 'uid1');
      expect(b.mitra, 'Budi');
      expect(b.batchKode, 'BATCH-001');
      expect(b.tglBungkus, '01/01/2026');
      expect(b.totalBerat, 10.5);
      expect(b.jumlahTray, 3);
      expect(b.status, 'TERBUNGKUS');
      expect(b.detailTrays.length, 1);
      expect(b.detailTrays.first.nama, 'TRAY-01');
    });

    test('jumlahTray fallback ke daftarNamaTray.length, lalu 1', () {
      final hasil1 = PembacaRiwayat.parseSatuDokumen('uid1', {
        'nama': 'Budi',
        'batch': [
          {
            'batchKode': 'B1',
            'tanggalFormatted': '01/01/2026',
            'daftarNamaTray': ['T1', 'T2'],
          },
        ],
      });
      expect(hasil1.first.jumlahTray, 2);

      final hasil2 = PembacaRiwayat.parseSatuDokumen('uid1', {
        'nama': 'Budi',
        'batch': [
          {'batchKode': 'B2', 'tanggalFormatted': '01/01/2026'},
        ],
      });
      expect(hasil2.first.jumlahTray, 1);
    });

    test('batch lama (tanpa batchKode/detailTrays) → format LEGACY', () {
      final hasil = PembacaRiwayat.parseSatuDokumen('uid1', {
        'nama': 'Budi',
        'batch': [
          {
            'nama': 'TRAY-OLD',
            'tanggalPanen': '22/01/2026',
            'hasilKg': '4.0',
            'status': 'selesai',
          },
        ],
      });

      expect(hasil.length, 1);
      final b = hasil.first;
      expect(b.batchKode, 'LEGACY-TRAY-OLD');
      expect(b.totalBerat, 4.0);
      expect(b.jumlahTray, 1);
      expect(b.status, 'SELESAI');
      expect(b.detailTrays.length, 1);
      expect(b.detailTrays.first.nama, 'TRAY-OLD');
    });

    test('batch bukan Map → di-skip', () {
      final hasil = PembacaRiwayat.parseSatuDokumen('uid1', {
        'nama': 'Budi',
        'batch': ['bukan map', 123],
      });
      expect(hasil, isEmpty);
    });

    test('nama mitra fallback "Mitra"', () {
      final hasil = PembacaRiwayat.parseSatuDokumen('uid1', {
        'batch': [
          {'batchKode': 'B1', 'tanggalFormatted': '01/01/2026'},
        ],
      });
      expect(hasil.first.mitra, 'Mitra');
    });

    test('beberapa batch dalam satu dokumen → beberapa DataBatch', () {
      final hasil = PembacaRiwayat.parseSatuDokumen('uid1', {
        'nama': 'Budi',
        'batch': [
          {'batchKode': 'B1', 'tanggalFormatted': '01/01/2026'},
          {'batchKode': 'B2', 'tanggalFormatted': '02/01/2026'},
        ],
      });
      expect(hasil.length, 2);
    });
  });
}
