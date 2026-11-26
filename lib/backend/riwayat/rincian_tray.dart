// ============================================================================
// MODEL RIWAYAT: RINCIAN TRAY
// ============================================================================
class RincianTray {
  final String nama;
  final String beratTelur;
  final String tglMulaiFormatted;
  final String tanggalPanen;
  final double hasilKg;
  final String status;
  final String gps;
  final String fotoUrl;
  final String fotoBase64;

  const RincianTray({
    required this.nama,
    required this.beratTelur,
    required this.tglMulaiFormatted,
    required this.tanggalPanen,
    required this.hasilKg,
    required this.status,
    required this.gps,
    required this.fotoUrl,
    required this.fotoBase64,
  });

  bool get isGagal => status.toUpperCase() == 'GAGAL';

  factory RincianTray.fromMap(Map<String, dynamic> map) {
    return RincianTray(
      nama: map['nama']?.toString() ?? 'Tray',
      beratTelur: map['beratTelur']?.toString() ?? '0',
      tglMulaiFormatted: map['tglMulaiFormatted']?.toString() ?? '-',
      tanggalPanen: map['tanggalPanen']?.toString() ?? '-',
      hasilKg: double.tryParse(map['hasilKg']?.toString() ?? '0') ?? 0.0,
      status: (map['status']?.toString() ?? 'BERHASIL').toUpperCase(),
      gps: map['gps']?.toString() ?? '-',
      fotoUrl: map['fotoUrl']?.toString() ?? '',
      fotoBase64: map['fotoBase64']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nama': nama,
      'beratTelur': beratTelur,
      'tglMulaiFormatted': tglMulaiFormatted,
      'tanggalPanen': tanggalPanen,
      'hasilKg': hasilKg,
      'status': status,
      'gps': gps,
      'fotoUrl': fotoUrl,
      'fotoBase64': fotoBase64,
    };
  }
}
