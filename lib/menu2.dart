import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_config.dart'; // ⚙️ HARI_AUTO_PANEN & konfigurasi lain

class MenuDua extends StatefulWidget {
  final List<Map<String, dynamic>> daftarSiklus;
  final Function(int, int) onKonfirmasiSehat;
  final Function(int, Map<String, dynamic>) onPanenOtomatis;
  final Function(int, Map<String, dynamic>) onGagalKePanen;

  const MenuDua({
    super.key,
    required this.daftarSiklus,
    required this.onKonfirmasiSehat,
    required this.onPanenOtomatis,
    required this.onGagalKePanen,
  });

  @override
  State<MenuDua> createState() => _MenuDuaState();
}

class _MenuDuaState extends State<MenuDua> {
  final Set<String> _processedTray = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: widget.daftarSiklus.isEmpty
          ? const Center(child: Text("Belum ada siklus aktif."))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: widget.daftarSiklus.length,
              itemBuilder: (context, index) {
                final d = widget.daftarSiklus[index];
                final String trayKey = d['nama']?.toString() ?? "tray_$index";

                // 1. Hitung Umur
                DateTime tgl = (d["tanggalMulai"] is Timestamp)
                    ? (d["tanggalMulai"] as Timestamp).toDate()
                    : DateTime.now();
                int hari = DateTime.now().difference(tgl).inDays;

                // 2. Logika Auto-Panen
                if (hari >= HARI_AUTO_PANEN && !_processedTray.contains(trayKey)) {
                  _processedTray.add(trayKey);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      widget.onPanenOtomatis(index, {...d, "status": "SIAP PANEN"});
                    }
                  });
                  return const SizedBox.shrink();
                }

                if (hari >= HARI_AUTO_PANEN) {
                  return const SizedBox.shrink();
                }

                // ═════════════════════════════════════════════════════════════════
                // 3. 🖼️ ATUR FILE GAMBAR (.PNG) SESUAI FASE DI SINI
                // ═════════════════════════════════════════════════════════════════
                String labelFase;
                String pathGambarFase;

                if (hari <= 5) {
                  labelFase = "TELUR";
                  pathGambarFase = "assets/images/telur.png";
                } else if (hari <= 13) {
                  labelFase = "BABY";
                  pathGambarFase = "assets/images/baby_maggot.png";
                } else {
                  labelFase = "MAGGOT LAPAR";
                  pathGambarFase = "assets/images/maggot_lapar.png";
                }
                // ═════════════════════════════════════════════════════════════════

                // 4. Logika Verifikasi
                bool isWaktunyaM1 = (hari >= 7 && hari < 14 && d['cekM1'] == null);
                bool isWaktunyaM2 = (hari >= 14 && hari < 21 && d['cekM2'] == null);
                bool perluVerifikasi = isWaktunyaM1 || isWaktunyaM2;

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        // 👇 GAMBAR BULAT MULUS DENGAN FILTER TINGGI (ANTI SEMUT)
                       leading: Container(
  width: 52,
  height: 52,
  decoration: BoxDecoration(
    shape: BoxShape.circle, // 👈 Mesin Flutter potong bulat halus sempurna (anti-gerigi)
    image: DecorationImage(
      image: ResizeImage(
        AssetImage(pathGambarFase),
        width: 150, // 👈 KUNCI MULUS: Memaksa gambar dihaluskan di memori HP
      ),
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
    ),
  ),
),
                        title: Text(
                          d['nama'],
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Text("Umur: $hari Hari | Fase: $labelFase"),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: perluVerifikasi ? Colors.red[100] : Colors.green[100],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            perluVerifikasi ? "BUTUH CEK" : "TERPANTAU",
                            style: TextStyle(
                              color: perluVerifikasi ? Colors.red : Colors.green,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      if (perluVerifikasi)
                        Container(
                          padding: const EdgeInsets.all(12),
                          color: Colors.yellow[50],
                          child: Column(
                            children: [
                              Text(
                                isWaktunyaM1
                                    ? "⚠️ Verifikasi Kesehatan Minggu 1 (Hari ke-7)"
                                    : "⚠️ Verifikasi Kesehatan Minggu 2 (Hari ke-14)",
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green),
                                      onPressed: () => widget.onKonfirmasiSehat(
                                          index, isWaktunyaM1 ? 1 : 2),
                                      child: const Text("SEHAT",
                                          style: TextStyle(color: Colors.white)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                          side: const BorderSide(color: Colors.red)),
                                      onPressed: () => widget.onGagalKePanen(
                                          index, {
                                        ...d,
                                        "status": "GAGAL",
                                        "tanggalSelesai": Timestamp.now()
                                      }),
                                      child: const Text("MATI"),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            hari < 7
                                ? "Menunggu Verifikasi Hari ke-7"
                                : (hari < 14
                                    ? "Verifikasi Berikutnya: Hari ke-14"
                                    : "Menunggu Panen (Hari ke-$HARI_AUTO_PANEN)"),
                            style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontStyle: FontStyle.italic),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}