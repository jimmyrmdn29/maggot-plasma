import 'package:flutter_test/flutter_test.dart';
import 'package:aplikasi_maggot/backend/riwayat/rincian_tray.dart';

void main() {
  group('RincianTray.fromMap', () {
    test('mengisi semua field dari map', () {
      final r = RincianTray.fromMap({
        'nama': 'TRAY-01',
        'beratTelur': '120',
        'tglMulaiFormatted': '01/01/2026',
        'tanggalPanen': '22/01/2026',
        'hasilKg': '5.5',
        'status': 'berhasil',
        'gps': '-6.2,106.8',
        'fotoUrl': 'https://x/y.jpg',
        'fotoBase64': 'AAAA',
      });
      expect(r.nama, 'TRAY-01');
      expect(r.beratTelur, '120');
      expect(r.tglMulaiFormatted, '01/01/2026');
      expect(r.tanggalPanen, '22/01/2026');
      expect(r.hasilKg, 5.5);
      expect(r.status, 'BERHASIL');
      expect(r.gps, '-6.2,106.8');
      expect(r.fotoUrl, 'https://x/y.jpg');
      expect(r.fotoBase64, 'AAAA');
    });

    test('field null/kosong → fallback', () {
      final r = RincianTray.fromMap({});
      expect(r.nama, 'Tray');
      expect(r.beratTelur, '0');
      expect(r.tglMulaiFormatted, '-');
      expect(r.tanggalPanen, '-');
      expect(r.hasilKg, 0.0);
      expect(r.status, 'BERHASIL');
      expect(r.gps, '-');
      expect(r.fotoUrl, '');
      expect(r.fotoBase64, '');
    });

    test('hasilKg string tidak valid → 0.0', () {
      final r = RincianTray.fromMap({'hasilKg': 'abc'});
      expect(r.hasilKg, 0.0);
    });
  });

  group('RincianTray.isGagal', () {
    test('status GAGAL (case-insensitive) → true', () {
      final r = RincianTray.fromMap({'status': 'gagal'});
      expect(r.isGagal, isTrue);
    });

    test('status lain → false', () {
      final r = RincianTray.fromMap({'status': 'BERHASIL'});
      expect(r.isGagal, isFalse);
    });
  });

  group('RincianTray.toMap round-trip', () {
    test('toMap mengembalikan map yang sama dengan fromMap', () {
      final r = RincianTray.fromMap({
        'nama': 'TRAY-02',
        'beratTelur': '80',
        'hasilKg': '3.2',
        'status': 'GAGAL',
      });
      final m = r.toMap();
      final r2 = RincianTray.fromMap(m);
      expect(r2.nama, r.nama);
      expect(r2.beratTelur, r.beratTelur);
      expect(r2.hasilKg, r.hasilKg);
      expect(r2.status, r.status);
    });
  });
}
