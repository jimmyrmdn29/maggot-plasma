import 'dart:math';

import 'package:flutter/material.dart';

import '../../../backend/estimasi/data_estimasi.dart';
import '../tema_estimasi.dart';

// ============================================================================
// TAMPILAN: TABEL ESTIMASI (DATA HALAMAN INI + STATE KOSONG)
// ============================================================================
class TampilanTabelEstimasi extends StatelessWidget {
  final List<DataEstimasi> dataHalamanIni;

  const TampilanTabelEstimasi({
    super.key,
    required this.dataHalamanIni,
  });

  @override
  Widget build(BuildContext context) {
    if (dataHalamanIni.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy_outlined, size: 50, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text("Data estimasi panen tidak ditemukan", style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const double minTabelWidth = 850;
        final double tableWidth = max(constraints.maxWidth, minTabelWidth);

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: SizedBox(
            width: tableWidth,
            child: Column(
              children: [
                Container(
                  height: 48,
                  color: TemaEstimasi.tableHeaderBg,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Row(
                    children: [
                      Expanded(flex: 3, child: Text("NAMA MITRA", style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text("NAMA TRAY", style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text("TELUR", style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text("TGL MULAI", style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text("EST. PANEN", style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text("EST. HASIL", style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: dataHalamanIni.length,
                    itemExtent: 52,
                    itemBuilder: (context, index) {
                      final item = dataHalamanIni[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                item.nama,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blueGrey.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    item.tray,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text("${item.telur.toStringAsFixed(1)} g"),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(item.tglMulaiStr),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                item.tglEstimasiStr,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: TemaEstimasi.success),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                "${item.estimasiKg.toStringAsFixed(1)} Kg",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1565C0),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
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
