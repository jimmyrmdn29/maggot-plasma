import 'package:flutter/material.dart';

import '../../../backend/riwayat/data_batch.dart';
import '../theme_riwayat.dart';

// ============================================================================
// TAMPILAN: TABEL RIWAYAT (DATA BATCH + STATE KOSONG)
// ============================================================================
class TampilanTabelRiwayat extends StatelessWidget {
  final List<DataBatch> dataHalamanIni;
  final Set<String> downloadingBatches;
  final ValueChanged<DataBatch> onLihatDetail;
  final ValueChanged<DataBatch> onUnduhBatch;

  const TampilanTabelRiwayat({
    super.key,
    required this.dataHalamanIni,
    required this.downloadingBatches,
    required this.onLihatDetail,
    required this.onUnduhBatch,
  });

  @override
  Widget build(BuildContext context) {
    if (dataHalamanIni.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 50, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text("Data batch tidak ditemukan", style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(TemaRiwayat.tableHeaderBg),
                columnSpacing: 22,
                dataRowMinHeight: 52,
                dataRowMaxHeight: 52,
                columns: const [
                  DataColumn(label: Text("NAMA MITRA", style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("KODE BATCH", style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("TGL BUNGKUS", style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("JUMLAH TRAY", style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("TOTAL HASIL", style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("AKSI", style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: dataHalamanIni.map((item) {
                  final bool isDownloading = downloadingBatches.contains(item.batchKode);

                  return DataRow(
                    cells: [
                      DataCell(Text(item.mitra, style: const TextStyle(fontWeight: FontWeight.w600))),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(item.batchKode, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      DataCell(Text(item.tglBungkus)),
                      DataCell(Text("${item.jumlahTray} Tray", style: const TextStyle(fontWeight: FontWeight.w500))),
                      DataCell(
                        Text(
                          "${item.totalBerat} Kg",
                          style: const TextStyle(fontWeight: FontWeight.bold, color: TemaRiwayat.accentBlue),
                        ),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_red_eye_outlined, color: Colors.blueGrey),
                              tooltip: "Lihat Detail & Foto",
                              onPressed: () => onLihatDetail(item),
                            ),
                            isDownloading
                                ? const Padding(
                                    padding: EdgeInsets.all(12.0),
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2.2, color: TemaRiwayat.success),
                                    ),
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.file_download_outlined, color: TemaRiwayat.success),
                                    tooltip: "Unduh Excel Batch Ini",
                                    onPressed: () => onUnduhBatch(item),
                                  ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}
