import 'package:flutter/material.dart';

class MenuEmpat extends StatelessWidget {
  final List<Map<String, dynamic>> daftarBatch;
  final Function(int) onHapusBatchManual;

  const MenuEmpat({
    super.key,
    required this.daftarBatch,
    required this.onHapusBatchManual,
  });

  @override
  Widget build(BuildContext context) {
    if (daftarBatch.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 70, color: Colors.grey[400]),
            const SizedBox(height: 12),
            const Text(
              "Belum ada riwayat batch panen.",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            const Text(
              "Bungkus panen di Menu 3 untuk membuat batch baru.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: daftarBatch.length,
        itemBuilder: (context, index) {
          final b = daftarBatch[index];

          // 🛡️ BACA DATA RINGKASAN BATCH (Defensive handling jika ada data lama)
          final String batchKode = b['batchKode'] ?? b['nama'] ?? "BATCH #${daftarBatch.length - index}";
          final String tanggal = b['tanggalFormatted'] ?? b['tanggalPanen'] ?? '-';
          final String totalBerat = (b['totalBeratKg'] ?? b['hasilKg'] ?? '0').toString();
          
          // Hitung tray (jika data baru pakai 'jumlahTray', jika data lama hitung dari 'detailTrays')
          final int jumlahTray = b['jumlahTray'] ?? (b['detailTrays'] != null ? (b['detailTrays'] as List).length : 1);

          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onLongPress: () {
                // Konfirmasi Hapus Batch
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("Hapus Batch Ini?"),
                    content: Text("Batch $batchKode akan dihapus dari riwayat."),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("Batal"),
                      ),
                      TextButton(
                        onPressed: () {
                          onHapusBatchManual(index);
                          Navigator.pop(ctx);
                        },
                        child: const Text("Hapus", style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. BARIS ATAS: KODE BATCH & STATUS BADGE
                    Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    // Bagian kiri dibungkus Expanded agar membatasi ruang teks kode batch jika layarnya sempit
    Expanded(
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.blue[100],
            child: Icon(Icons.inventory_2, color: Colors.blue[800], size: 18),
          ),
          const SizedBox(width: 10),  // Bungkus teks dengan Expanded + overflow ellipsis agar aman di HP sekecil apa pun
          Expanded(
            child: Text(
              batchKode,
              maxLines: 1,
              overflow: TextOverflow.ellipsis, // Otomatis jadi "KODE-BAT..." jika kepanjangan
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    ),
    const SizedBox(width: 10), // Jarak aman antara teks kode dan badge
                       
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: Text(
                            "TERBUNGKUS",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[800],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // 2. TANGGAL PEMBUNGKUSAN
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(
                          "Waktu: $tanggal",
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),

                    const Divider(height: 22),

                    // 3. BARIS UTAMA: TOTAL BERAT & JUMLAH TRAY
                    Row(
                      children: [
                        // KOTAK TOTAL BERAT
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.scale, color: Colors.orange[800], size: 22),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Total Berat",
                                      style: TextStyle(fontSize: 11, color: Colors.black54),
                                    ),
                                    Text(
                                      "$totalBerat Kg",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange[900],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(width: 10),

                        // KOTAK JUMLAH TRAY
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.grid_view_rounded, color: Colors.blue[800], size: 22),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Jumlah Tray",
                                      style: TextStyle(fontSize: 11, color: Colors.black54),
                                    ),
                                    Text(
                                      "$jumlahTray Tray",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[900],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}