// page_riwayat.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'riwayat_controller.dart';
import 'theme_riwayat.dart';
import 'widget/dialog_detail_tray_riwayat.dart';
import 'widget/dialog_filter_tanggal_riwayat.dart';
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
  StreamSubscription<QuerySnapshot>? _langgananData;
  bool _sedangMemuat = true;
  String? _pesanError;

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

    _langgananData = _controller.usersStream.listen(
      (snapshot) {
        _controller.parseMasterList(snapshot.docs);
        if (!mounted) return;
        setState(() {
          _sedangMemuat = false;
          _pesanError = null;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _sedangMemuat = false;
          _pesanError = error.toString();
        });
      },
    );
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _langgananData?.cancel();
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }



  // ==========================================================================
  // 2. BUILD (KOMPOSISI HALAMAN)
  // ==========================================================================
  @override
  Widget build(BuildContext context) {
    if (_sedangMemuat) {
      return const Scaffold(
        backgroundColor: TemaRiwayat.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_pesanError != null) {
      return Scaffold(
        backgroundColor: TemaRiwayat.background,
        body: Center(child: Text("Terjadi kesalahan: $_pesanError")),
      );
    }

    final totalData = _controller.totalData;
    final totalHalaman = _controller.totalHalaman;
    final startIndex = _controller.startIndex;
    final endIndex = _controller.endIndex;
    final dataHalamanIni = _controller.dataHalamanIni;

    return Scaffold(
      backgroundColor: TemaRiwayat.background,
      body: Column(
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
            onBukaFilterTanggal: () => tampilkanDialogFilterTanggalRiwayat(context, _controller),
            onHapusFilterTanggal: () => _controller.hapusFilterTanggal(),
          ),
          const Divider(height: 1, thickness: 1),
          Expanded(
            child: TampilanTabelRiwayat(
              dataHalamanIni: dataHalamanIni,
              downloadingBatches: _controller.downloadingBatches,
              onLihatDetail: (item) => tampilkanDetailTrayRiwayat(context, _controller, item),
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
      ),
    );
  }
}
