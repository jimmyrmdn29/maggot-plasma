import 'package:flutter/material.dart';

// ============================================================================
// TAMPILAN: TAB ANTREAN VERIFIKASI PANEN
// (Daftar tray antrean + kartu verifikasi + kondisi kosong)
// ============================================================================
class TampilanAntreanTray extends StatelessWidget {
  final List<Map<String, dynamic>> antrean;
  final bool dapatAksi;
  final bool adaTrayDalamKantong;
  final TextEditingController Function(String trayName) controller;
  final Future<void> Function(Map<String, dynamic> data) onVerifikasi;

  const TampilanAntreanTray({
    super.key,
    required this.antrean,
    required this.dapatAksi,
    required this.adaTrayDalamKantong,
    required this.controller,
    required this.onVerifikasi,
  });

  @override
  Widget build(BuildContext context) {
    if (antrean.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 70, color: Colors.green[400]),
            const SizedBox(height: 12),
            const Text("Semua Tray Telah Diverifikasi", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              adaTrayDalamKantong ? "Buka tab 'Siap Kirim' untuk membungkus." : "Semua tray hari ini telah selesai diproses.",
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: antrean.length,
      itemBuilder: (context, index) {
        final d = antrean[index];
        final String nama = d['nama']?.toString() ?? 'Tray';
        final bool isGagal = d['status'] == "GAGAL";
        final TextEditingController ctl = controller(nama);

        return Card(
          elevation: 1.5,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: isGagal ? Colors.red[100] : Colors.green[100],
                      child: Icon(
                        isGagal ? Icons.close : Icons.eco,
                        color: isGagal ? Colors.red[800] : Colors.green[800],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(nama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(
                            isGagal ? "Kondisi: Panen Gagal" : "Siap Panen",
                            style: TextStyle(
                              fontSize: 12,
                              color: isGagal ? Colors.red[700] : Colors.green[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (!isGagal)
                  TextField(
                    controller: ctl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: "Berat Hasil Panen (Kg)",
                      suffixText: "Kg",
                      prefixIcon: const Icon(Icons.scale_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.red, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Wajib ambil foto bukti maggot mati.",
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isGagal ? Colors.red[700] : Colors.blue[800],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: dapatAksi ? () => onVerifikasi(d) : null,
                    icon: const Icon(Icons.camera_alt, size: 18),
                    label: Text(
                      isGagal ? "FOTO BUKTI MATI" : "AMBIL FOTO & VERIFIKASI",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
