// page_riwayat.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../backend/riwayat/rincian_tray.dart';
import '../../backend/riwayat/data_batch.dart';
import '../../backend/riwayat/pembaca_riwayat.dart';
import 'riwayat_controller.dart';
import 'theme_riwayat.dart';
import 'widget/tampilan_toolbar_riwayat.dart';
import 'widget/tampilan_tabel_riwayat.dart';
import 'widget/tampilan_pagination_riwayat.dart';
import 'widget/tampilan_footer_riwayat.dart';

// ============================================================================
// 1. HALAMAN RIWAYAT (PLUG & PLAY)
// ============================================================================
class PageRiwayat extends StatefulWidget {
  const PageRiwayat({super.key});

  @override
  State<PageRiwayat> createState() => _PageRiwayatState();
}

class _PageRiwayatState extends State<PageRiwayat> {
  late final RiwayatController _controller;

  @override
  void initState() {
    super.initState();
    _controller = RiwayatController(
      onSnackbar: (msg, {isError = false, color}) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: isError ? Colors.red[700] : (color ?? TemaRiwayat.success),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
    _controller.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  // ==========================================================================
  // DIALOG FILTER TANGGAL
  // ==========================================================================
  Future<void> _bukaFilterTanggalCepat(BuildContext context) async {
    final now = DateTime.now();
    DateTime tempStart = _controller.selectedRange?.start ?? now.subtract(const Duration(days: 7));
    DateTime tempEnd = _controller.selectedRange?.end ?? now;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 4,
              child: Container(
                width: 420,
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Pilih Rentang Tanggal",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        )
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text("PILIHAN CEPAT", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 8),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildPresetChip("Hari Ini", () {
                          final today = DateTime(now.year, now.month, now.day);
                          _controller.terapkanRentangBaru(DateTimeRange(start: today, end: today));
                          Navigator.pop(ctx);
                        }),
                        _buildPresetChip("7 Hari Terakhir", () {
                          final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
                          final end = DateTime(now.year, now.month, now.day);
                          _controller.terapkanRentangBaru(DateTimeRange(start: start, end: end));
                          Navigator.pop(ctx);
                        }),
                        _buildPresetChip("Bulan Ini", () {
                          final start = DateTime(now.year, now.month, 1);
                          final end = DateTime(now.year, now.month + 1, 0);
                          _controller.terapkanRentangBaru(DateTimeRange(start: start, end: end));
                          Navigator.pop(ctx);
                        }),
                        _buildPresetChip("Bulan Lalu", () {
                          final start = DateTime(now.year, now.month - 1, 1);
                          final end = DateTime(now.year, now.month, 0);
                          _controller.terapkanRentangBaru(DateTimeRange(start: start, end: end));
                          Navigator.pop(ctx);
                        }),
                      ],
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Divider(height: 1),
                    ),

                    const Text("RENTANG KUSTOM", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: tempStart,
                                firstDate: DateTime(now.year - 3),
                                lastDate: DateTime(now.year + 1),
                              );
                              if (picked != null) {
                                setModalState(() {
                                  tempStart = picked;
                                  if (tempEnd.isBefore(tempStart)) {
                                    tempEnd = tempStart;
                                  }
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Dari", style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  const SizedBox(height: 2),
                                  Text(
                                    DateFormat('dd MMM yyyy').format(tempStart),
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: tempEnd.isBefore(tempStart) ? tempStart : tempEnd,
                                firstDate: tempStart,
                                lastDate: DateTime(now.year + 1),
                              );
                              if (picked != null) {
                                setModalState(() {
                                  tempEnd = picked;
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Sampai", style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  const SizedBox(height: 2),
                                  Text(
                                    DateFormat('dd MMM yyyy').format(tempEnd),
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TemaRiwayat.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          _controller.terapkanRentangBaru(DateTimeRange(start: tempStart, end: tempEnd));
                          Navigator.pop(ctx);
                        },
                        child: const Text("TERAPKAN TANGGAL", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPresetChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF37474F))),
      backgroundColor: TemaRiwayat.surfaceGrey,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      onPressed: onTap,
    );
  }

  // ==========================================================================
  // DIALOG DETAIL TRAY & BUKTI FOTO
  // ==========================================================================
  void _tampilkanDetailTrayDialog(DataBatch batch) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final List<RincianTray> detail = await _controller.ambilDetailTrays(batch);

    if (!mounted) return;
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
                                  ? () => _tampilkanFotoBesar(
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

  void _tampilkanFotoBesar(
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

  // ==========================================================================
  // 2. BUILD (KOMPOSISI HALAMAN)
  // ==========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TemaRiwayat.background,
      body: StreamBuilder<QuerySnapshot>(
        stream: _controller.usersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Terjadi kesalahan: ${snapshot.error}"));
          }

          _controller.parseMasterList(snapshot.data?.docs ?? []);

          final totalData = _controller.totalData;
          final totalHalaman = _controller.totalHalaman;
          final startIndex = _controller.startIndex;
          final endIndex = _controller.endIndex;
          final dataHalamanIni = _controller.dataHalamanIni;

          return Column(
            children: [
              TampilanToolbarRiwayat(
                controller: _controller.searchController,
                onCariChanged: (v) {
                  _controller.onSearchChanged(v);
                },
                sortTerbaru: _controller.sortTerbaru,
                onSortChange: (v) {
                  _controller.onSortChange(v);
                },
                selectedRange: _controller.selectedRange,
                onBukaFilterTanggal: () => _bukaFilterTanggalCepat(context),
                onHapusFilterTanggal: () => _controller.hapusFilterTanggal(),
              ),
              const Divider(height: 1, thickness: 1),
              Expanded(
                child: TampilanTabelRiwayat(
                  dataHalamanIni: dataHalamanIni,
                  downloadingBatches: _controller.downloadingBatches,
                  onLihatDetail: (item) => _tampilkanDetailTrayDialog(item),
                  onUnduhBatch: (item) => _controller.exportSingleBatchToExcel(item),
                ),
              ),
              const Divider(height: 1, thickness: 1),
              TampilanPaginationRiwayat(
                totalData: totalData,
                totalHalaman: totalHalaman,
                startIndex: startIndex,
                endIndex: endIndex,
                halamanAktif: _controller.halamanAktif,
                barisPerHalaman: _controller.barisPerHalaman,
                opsiBaris: RiwayatController.opsiBaris,
                onHalamanChange: (page) => _controller.onHalamanChange(page),
                onBarisChange: (val) => _controller.onBarisChange(val),
              ),
              const Divider(height: 1, thickness: 1),
              TampilanFooterRiwayat(data: _controller.filtered),
            ],
          );
        },
      ),
    );
  }
}
