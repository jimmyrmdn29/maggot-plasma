import 'package:flutter_test/flutter_test.dart';
import 'package:aplikasi_maggot/app_config.dart';

void main() {
  testWidgets('Konfigurasi aplikasi terdefinisi dengan benar',
      (WidgetTester tester) async {
    expect(RESET_COUNTER_TRAY_SETIAP_N_BULAN, greaterThanOrEqualTo(0));
    expect(HARI_AUTO_PANEN, greaterThan(0));
    expect(ESTIMASI_RASIO_TELUR_KE_HASIL, greaterThan(0));
    expect(KUALITAS_FOTO_BUKTI, inInclusiveRange(1, 100));
  });

  testWidgets('Fungsi cekPerluResetCounter berjalan benar',
      (WidgetTester tester) async {
    final userDataLama = <String, dynamic>{
      'terakhirResetCounter': null,
      'tanggalDibuat': null,
    };
    expect(cekPerluResetCounter(userDataLama), isNotNull);
  });
}
