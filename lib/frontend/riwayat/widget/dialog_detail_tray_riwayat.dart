import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../backend/riwayat/rincian_tray.dart';
import '../../../backend/riwayat/data_batch.dart';
import '../../../backend/riwayat/pembaca_riwayat.dart';
import '../riwayat_controller.dart';
import '../theme_riwayat.dart';

Future<void> tampilkanDetailTrayRiwayat(
  BuildContext context,
  RiwayatController controller,
  DataBatch batch,
) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const Center(child: CircularProgressIndicator()),
  );

  final List<RincianTray> detail = await controller.ambilDetailTrays(batch);

  if (!context.mounted) return;
  Navigator.pop(context);

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(batch.batchKode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          Text("Mitra: ${batch.mitra} | ${batch.tglBungkus}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
      content: SizedBox(
        width: 550,
        child: detail.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(20.0),
                child: Center(child: Text("Tidak ada rincian tray tersimpan di database.")),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: detail.length,
                itemBuilder: (context, i) {
                  final t = detail[i];
                  final Uint8List? fotoBytes = PembacaRiwayat.safeDecodeBase64(t.fotoBase64);
                  final bool hasImage = t.fotoUrl.isNotEmpty || fotoBytes != null;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    color: t.isGagal ? TemaRiwayat.failureBg : TemaRiwayat.cardBg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: hasImage
                                ? () => tampilkanFotoBesarRiwayat(
                                      context,
                                      bytes: fotoBytes,
                                      url: t.fotoUrl,
                                      namaTray: t.nama,
                                      gps: t.gps,
                                    )
                                : null,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: fotoBytes != null
                                  ? Image.memory(
                                      fotoBytes,
                                      width: 65,
                                      height: 65,
                                      cacheWidth: 140,
                                      cacheHeight: 140,
                                      fit: BoxFit.cover,
                                      filterQuality: FilterQuality.medium,
                                    )
                                  : (t.fotoUrl.isNotEmpty
                                      ? Image.network(
                                          t.fotoUrl,
                                          width: 65,
                                          height: 65,
                                          cacheWidth: 140,
                                          cacheHeight: 140,
                                          fit: BoxFit.cover,
                                          filterQuality: FilterQuality.medium,
                                        )
                                      : Container(
                                          width: 65,
                                          height: 65,
                                          color: TemaRiwayat.borderGrey,
                                          child: const Icon(Icons.no_photography, size: 24, color: Colors.grey),
                                        )),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.nama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 2),
                                Text(
                                  t.isGagal ? "Status: MATI / GAGAL" : "Hasil: ${t.hasilKg} Kg (Telur: ${t.beratTelur} g)",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: t.isGagal ? Colors.red[800] : Colors.green[800],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text("GPS: ${t.gps}", style: const TextStyle(fontSize: 11, color: Colors.black87)),
                                Text(
                                  "Mulai: ${t.tglMulaiFormatted} | Panen: ${t.tanggalPanen}",
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("TUTUP")),
      ],
    ),
  );
}

void tampilkanFotoBesarRiwayat(
  BuildContext context, {
  Uint8List? bytes,
  String? url,
  required String namaTray,
  required String gps,
}) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 650),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text("Bukti Panen: $namaTray", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: bytes != null
                      ? Image.memory(bytes, fit: BoxFit.contain, filterQuality: FilterQuality.medium)
                      : (url != null && url.isNotEmpty
                          ? Image.network(url, fit: BoxFit.contain, filterQuality: FilterQuality.medium)
                          : const Center(child: Icon(Icons.no_photography, size: 50, color: Colors.grey))),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: TemaRiwayat.tableHeaderBg, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text("Koordinat GPS: $gps", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                ],
              ),
            )
          ],
        ),
      ),
    ),
  );
}