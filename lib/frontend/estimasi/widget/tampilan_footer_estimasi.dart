import 'package:flutter/material.dart';

import '../../../backend/estimasi/data_estimasi.dart';
import '../tema_estimasi.dart';

// ============================================================================
// TAMPILAN: FOOTER ESTIMASI (TOTAL & EXPORT EXCEL)
// ============================================================================
class TampilanFooterEstimasi extends StatelessWidget {
  final List<DataEstimasi> data;
  final bool sedangExport;
  final bool exportSuccess;
  final Future<void> Function(List<DataEstimasi> data) onExport;

  const TampilanFooterEstimasi({
    super.key,
    required this.data,
    required this.sedangExport,
    required this.exportSuccess,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final double total = data.fold(0.0, (sum, item) => sum + item.estimasiKg);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_outlined, color: TemaEstimasi.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                "Total Record: ${data.length} Tray",
                style: const TextStyle(fontSize: 13, color: Color(0xFF424242), fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Text(
                "Total Estimasi: ${total.toStringAsFixed(1)} Kg",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: TemaEstimasi.primary,
                ),
              ),
              const SizedBox(width: 20),
              ElevatedButton.icon(
                onPressed: (data.isEmpty || sedangExport) ? null : () => onExport(data),
                icon: Icon(
                  exportSuccess ? Icons.check_circle : Icons.file_download_outlined,
                  size: 18,
                  color: Colors.white,
                ),
                label: Text(
                  exportSuccess ? "BERHASIL!" : "UNDUH EXCEL",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: exportSuccess ? TemaEstimasi.successDark : TemaEstimasi.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
