import 'package:flutter_test/flutter_test.dart';
import 'package:aplikasi_maggot/backend/app_config.dart';

void main() {
  test('Konfigurasi aplikasi terdefinisi dengan benar', () {
    expect(HARI_AUTO_PANEN, greaterThan(0));
    expect(ESTIMASI_RASIO_TELUR_KE_HASIL, greaterThan(0));
    expect(KUALITAS_FOTO_BUKTI, inInclusiveRange(1, 100));
  });
}
