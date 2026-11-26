import 'package:flutter/material.dart';

import 'verifikasi_panen_controller.dart';
import 'widget/dialog_verifikasi_panen.dart';
import 'widget/tampilan_halaman_panen.dart';

// ============================================================================
// HALAMAN: PEMBERIAN VERIFIKASI & BUNGKUS PANEN (MENU 3)
// ============================================================================
class PageVerifikasiPanen extends StatefulWidget {
  final List<Map<String, dynamic>> daftarPanen;
  final Future<void> Function(Map<String, dynamic> paketBatch) onBungkusBatch;
  final Future<void> Function(String batchKode, List<dynamic> detailTrays) onUpdateFotoBatch;

  const PageVerifikasiPanen({
    super.key,
    required this.daftarPanen,
    required this.onBungkusBatch,
    required this.onUpdateFotoBatch,
  });

  @override
  State<PageVerifikasiPanen> createState() => _PageVerifikasiPanenState();
}

class _PageVerifikasiPanenState extends State<PageVerifikasiPanen>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final VerifikasiPanenController _controller;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _controller = VerifikasiPanenController(
      daftarPanen: widget.daftarPanen,
      onBungkusBatch: widget.onBungkusBatch,
      onUpdateFotoBatch: widget.onUpdateFotoBatch,
      isMounted: () => mounted,
      onSnackbar: _showSnackbar,
      onBungkusSelesai: () => _tabController.animateTo(0),
      onGpsMati: () => DialogVerifikasiPanen.tampilkanDialogGpsMati(context),
      onIzinPermanen: () => DialogVerifikasiPanen.tampilkanDialogIzinPermanen(context),
      onFakeGps: () => DialogVerifikasiPanen.tampilkanDialogFakeGps(context),
    );
    _controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.disposeController();
    _tabController.dispose();
    super.dispose();
  }

  void _showSnackbar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red[800] : Colors.green[800],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ==========================================================
  // USER INTERFACE
  // ==========================================================
  @override
  Widget build(BuildContext context) {
    super.build(context);

    return TampilanHalamanPanen(
      antrean: _controller.antreanAktif,
      kantong: _controller.kantongRahasia,
      sedangMemproses: _controller.isProcessingBungkus,
      dapatAksi: _controller.dapatAksi,
      sedangMuat: _controller.isInitLoading,
      pesanMuat: "Memuat data panen...",
      tabController: _tabController,
      controller: _controller.getController,
      onVerifikasi: (Map<String, dynamic> data) => _controller.verifikasi(data),
      onBatalkan: (int index) => _controller.batalkanDariKantong(index),
      onBungkus: () => _controller.prosesBungkusInstan(),
      sedangLoading: _controller.loading,
      pesanLoading: _controller.statusPesanLoading,
    );
  }
}
