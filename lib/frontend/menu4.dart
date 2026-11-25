import 'package:flutter/material.dart';

// =========================================================================
// 1. WIDGET UTAMA (MENU EMPAT)
// =========================================================================
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
      return const _EmptyBatchState();
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: daftarBatch.length,
        itemBuilder: (context, index) {
          final data = daftarBatch[index];
          return _BatchCard(
            index: index,
            totalItems: daftarBatch.length,
            batchData: data,
            onDelete: () => onHapusBatchManual(index),
          );
        },
      ),
    );
  }
}

// =========================================================================
// 2. WIDGET KARTU BATCH
// =========================================================================
class _BatchCard extends StatelessWidget {
  final int index;
  final int totalItems;
  final Map<String, dynamic> batchData;
  final VoidCallback onDelete;

  const _BatchCard({
    required this.index,
    required this.totalItems,
    required this.batchData,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // 🛡️ Ekstraksi data defensif (Mendukung data baru maupun data lama)
    final String batchKode = batchData['batchKode'] ?? batchData['nama'] ?? "BATCH #${totalItems - index}";
    final String tanggal = batchData['tanggalFormatted'] ?? batchData['tanggalPanen'] ?? '-';
    final String totalBerat = (batchData['totalBeratKg'] ?? batchData['hasilKg'] ?? '0').toString();
    final int jumlahTray = batchData['jumlahTray'] ?? (batchData['detailTrays'] != null ? (batchData['detailTrays'] as List).length : 1);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onLongPress: () => _tampilkanDialogHapus(context, batchKode),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header: Kode Batch & Badge
              _buildHeader(batchKode),
              const SizedBox(height: 10),

              // 2. Tanggal
              _buildTanggal(tanggal),
              const Divider(height: 22),

              // 3. Ringkasan Angka (Metrik)
              Row(
                children: [
                  Expanded(
                    child: _MetricBox(
                      icon: Icons.scale,
                      baseColor: Colors.orange,
                      title: "Total Berat",
                      value: "$totalBerat Kg",
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricBox(
                      icon: Icons.grid_view_rounded,
                      baseColor: Colors.blue,
                      title: "Jumlah Tray",
                      value: "$jumlahTray Tray",
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String batchKode) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.blue[100],
                child: Icon(Icons.inventory_2, color: Colors.blue[800], size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  batchKode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
        const SizedBox(width: 10),
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
    );
  }

  Widget _buildTanggal(String tanggal) {
    return Row(
      children: [
        const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey),
        const SizedBox(width: 6),
        Text(
          "Waktu: $tanggal",
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  void _tampilkanDialogHapus(BuildContext context, String batchKode) {
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
              onDelete();
              Navigator.pop(ctx);
            },
            child: const Text("Hapus", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// 3. WIDGET KOTAK METRIK (Reusable Component)
// =========================================================================
class _MetricBox extends StatelessWidget {
  final IconData icon;
  final MaterialColor baseColor;
  final String title;
  final String value;

  const _MetricBox({
    required this.icon,
    required this.baseColor,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: baseColor[50],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: baseColor[800], size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: baseColor[900],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// 4. WIDGET TAMPILAN KOSONG (EMPTY STATE)
// =========================================================================
class _EmptyBatchState extends StatelessWidget {
  const _EmptyBatchState();

  @override
  Widget build(BuildContext context) {
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
}