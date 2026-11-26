import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

// ============================================================================
// TAMPILAN: DIALOG VERIFIKASI PANEN
// (Peringatan & konfirmasi: GPS mati, izin lokasi ditolak, fake GPS)
// ============================================================================
class DialogVerifikasiPanen {
  DialogVerifikasiPanen._();

  static void tampilkanDialogGpsMati(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.location_off, color: Colors.red, size: 26),
            SizedBox(width: 8),
            Text("GPS Belum Aktif!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text(
          "GPS wajib aktif agar titik koordinat panen terekam. (GPS satelit tetap bekerja meski tanpa kuota/sinyal).",
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("BATAL", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[800],
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await Geolocator.openLocationSettings();
            },
            icon: const Icon(Icons.settings, size: 16),
            label: const Text("AKTIFKAN GPS"),
          ),
        ],
      ),
    );
  }

  static void tampilkanDialogIzinPermanen(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Izin Lokasi Diblokir", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text(
          "Silakan izinkan akses lokasi melalui Pengaturan Aplikasi.",
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("BATAL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[800],
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await Geolocator.openAppSettings();
            },
            child: const Text("PENGATURAN"),
          ),
        ],
      ),
    );
  }

  static void tampilkanDialogFakeGps(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.security, color: Colors.red, size: 26),
            SizedBox(width: 8),
            Text("Peringatan Keamanan", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text(
          "Terdeteksi lokasi palsu (Fake GPS / Mock Location)! Sistem menolak titik koordinat tiruan. Mohon matikan aplikasi Fake GPS untuk memverifikasi panen.",
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[800], foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text("SAYA MENGERTI"),
          ),
        ],
      ),
    );
  }
}
