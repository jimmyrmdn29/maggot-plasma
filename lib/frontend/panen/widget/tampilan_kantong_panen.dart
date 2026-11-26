import 'dart:io';

import 'package:flutter/material.dart';

// ============================================================================
// TAMPILAN: TAB KANTONG PANEN
// (Daftar tray siap kirim + kartu + kondisi kosong)
// ============================================================================
class TampilanKantongPanen extends StatelessWidget {
  final List<Map<String, dynamic>> kantong;
  final bool dapatAksi;
  final Future<void> Function(int index) onBatalkan;

  const TampilanKantongPanen({
    super.key,
    required this.kantong,
    required this.dapatAksi,
    required this.onBatalkan,
  });

  @override
  Widget build(BuildContext context) {
    if (kantong.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 10),
            const Text(
              "Belum Ada Tray Siap Kirim",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            const Text(
              "Verifikasi tray terlebih dahulu dari Tab Antrean.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: kantong.length,
      itemBuilder: (context, index) {
        final item = kantong[index];
        final bool isGagal = item['status'] == "GAGAL";
        final String? localPath = item['fotoLocalPath'];

        Widget fotoThumbnail;
        if (localPath != null && File(localPath).existsSync()) {
          fotoThumbnail = Image.file(
            File(localPath),
            width: 55,
            height: 55,
            fit: BoxFit.cover,
          );
        } else {
          fotoThumbnail = Container(
            width: 55,
            height: 55,
            color: Colors.grey[300],
            child: const Icon(Icons.camera_alt, color: Colors.grey),
          );
        }

        return Card(
          elevation: 1.5,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: fotoThumbnail,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['nama'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        isGagal ? "Status: GAGAL" : "Hasil: ${item['hasilKg']} Kg",
                        style: TextStyle(
                          color: isGagal ? Colors.red : Colors.green[800],
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Text("📍 GPS: ${item['gps']}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: "Kembalikan ke antrean",
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: dapatAksi ? () => onBatalkan(index) : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
