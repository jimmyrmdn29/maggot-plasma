import 'package:flutter/material.dart';

import '../../../backend/riwayat/data_batch.dart';
import '../theme_riwayat.dart';

// ============================================================================
// TAMPILAN: FOOTER RIWAYAT (TOTAL PANEN PER HALAMAN)
// ============================================================================
class TampilanFooterRiwayat extends StatelessWidget {
  final List<DataBatch> data;

  const TampilanFooterRiwayat({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    double totalKg = data.fold(0.0, (acc, item) => acc + item.totalBerat);
    int totalTray = data.fold(0, (acc, item) => acc + item.jumlahTray);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_outlined, color: Colors.blueGrey, size: 20),
              const SizedBox(width: 8),
              Text(
                "Total Record: ${data.length} Batch ($totalTray Tray)",
                style: const TextStyle(fontSize: 13, color: Color(0xFF424242), fontWeight: FontWeight.w500),
              ),
            ],
          ),
          Text(
            "Total Panen: ${totalKg.toStringAsFixed(1)} Kg",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: TemaRiwayat.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}
