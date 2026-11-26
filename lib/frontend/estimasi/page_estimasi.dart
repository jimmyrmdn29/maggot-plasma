// page_Estimasi.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'estimasi_controller.dart';
import 'tema_estimasi.dart';
import 'widget/dialog_filter_tanggal.dart';
import 'widget/tampilan_footer_estimasi.dart';
import 'widget/tampilan_pagination_estimasi.dart';
import 'widget/tampilan_tabel_estimasi.dart';
import 'widget/tampilan_toolbar_estimasi.dart';

// ============================================================================
// 1. HALAMAN ESTIMASI (ADMIN) — PLUG & PLAY
// ============================================================================
class PageEstimasi extends StatefulWidget {
  const PageEstimasi({super.key});

  @override
  State<PageEstimasi> createState() => _PageEstimasiState();
}

class _PageEstimasiState extends State<PageEstimasi> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final EstimasiController _controller;

  @override
  void initState() {
    super.initState();
    _controller = EstimasiController(
      onSnackbar: (msg, {isError = false}) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: isError ? Colors.red : null,
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

  Future<void> _bukaFilterTanggalCepat(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => DialogFilterTanggal(
        rangeAkhir: _controller.selectedRange,
        onTerapkan: _controller.terapkanRentangBaru,
      ),
    );
  }

  // ==========================================================
  // USER INTERFACE
  // ==========================================================
  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: TemaEstimasi.background,
      body: StreamBuilder<QuerySnapshot>(
        stream: _controller.usersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Terjadi kesalahan: ${snapshot.error}"));
          }

          final rawDocs = snapshot.data?.docs ?? [];
          _controller.parseAndFilter(rawDocs);

          return Column(
            children: [
              TampilanToolbarEstimasi(
                controller: _controller.searchController,
                onCariChanged: _controller.onSearchChanged,
                sortTerbaru: _controller.sortTerbaru,
                onSortChange: _controller.onSortChange,
                selectedRange: _controller.selectedRange,
                onBukaFilterTanggal: () => _bukaFilterTanggalCepat(context),
                onHapusFilterTanggal: _controller.hapusFilterTanggal,
              ),
              const Divider(height: 1, thickness: 1),
              Expanded(
                child: TampilanTabelEstimasi(dataHalamanIni: _controller.dataHalamanIni),
              ),
              const Divider(height: 1, thickness: 1),
              TampilanPaginationEstimasi(
                totalData: _controller.totalData,
                totalHalaman: _controller.totalHalaman,
                startIndex: _controller.startIndex,
                endIndex: _controller.endIndex,
                halamanAktif: _controller.halamanAktif,
                barisPerHalaman: _controller.barisPerHalaman,
                opsiBaris: EstimasiController.opsiBaris,
                onHalamanChange: _controller.onHalamanChange,
                onBarisChange: _controller.onBarisChange,
              ),
              const Divider(height: 1, thickness: 1),
              TampilanFooterEstimasi(
                data: _controller.sorted,
                sedangExport: _controller.isExporting,
                exportSuccess: _controller.isExportSuccess,
                onExport: _controller.exportToExcel,
              ),
            ],
          );
        },
      ),
    );
  }
}
