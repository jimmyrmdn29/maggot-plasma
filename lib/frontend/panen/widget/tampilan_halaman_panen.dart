import 'package:flutter/material.dart';

import 'tampilan_antrean_tray.dart';
import 'tampilan_kantong_panen.dart';
import 'tampilan_loading_panen.dart';
import 'tampilan_muat_panen.dart';
import 'tampilan_tombol_bungkus.dart';

// ============================================================================
// TAMPILAN: HALAMAN UTAMA VERIFIKASI & BUNGKUS PANEN
// (Scaffold + TabBar + komposisi tab; tanpa logika state)
// ============================================================================
class TampilanHalamanPanen extends StatelessWidget {
  final List<Map<String, dynamic>> antrean;
  final List<Map<String, dynamic>> kantong;
  final bool sedangMemproses;
  final bool dapatAksi;
  final bool sedangMuat;
  final String pesanMuat;
  final TabController tabController;
  final TextEditingController Function(String trayName) controller;
  final Future<void> Function(Map<String, dynamic> data) onVerifikasi;
  final Future<void> Function(int index) onBatalkan;
  final Future<void> Function() onBungkus;
  final bool sedangLoading;
  final String pesanLoading;

  const TampilanHalamanPanen({
    super.key,
    required this.antrean,
    required this.kantong,
    required this.sedangMemproses,
    required this.dapatAksi,
    required this.sedangMuat,
    required this.pesanMuat,
    required this.tabController,
    required this.controller,
    required this.onVerifikasi,
    required this.onBatalkan,
    required this.onBungkus,
    required this.sedangLoading,
    required this.pesanLoading,
  });

  @override
  Widget build(BuildContext context) {
    if (sedangMuat) {
      return TampilanMuatPanen(pesan: pesanMuat);
    }

    final List<Map<String, dynamic>> antreanAktif = antrean;
    final List<Map<String, dynamic>> kantongRahasia = kantong;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          "Verifikasi Panen Maggot",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        bottom: TabBar(
          controller: tabController,
          labelColor: Colors.blue[900],
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: Colors.blue[900],
          indicatorWeight: 3,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.format_list_bulleted, size: 18),
                  const SizedBox(width: 8),
                  Text("Antrean (${antreanAktif.length})", style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.archive_outlined, size: 18),
                  const SizedBox(width: 8),
                  Text("Siap Kirim (${kantongRahasia.length})", style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: tabController,
            children: [
              TampilanAntreanTray(
                antrean: antreanAktif,
                dapatAksi: dapatAksi,
                adaTrayDalamKantong: kantongRahasia.isNotEmpty,
                controller: controller,
                onVerifikasi: onVerifikasi,
              ),
              TampilanKantongPanen(
                kantong: kantongRahasia,
                dapatAksi: dapatAksi,
                onBatalkan: onBatalkan,
              ),
            ],
          ),
          if (sedangLoading)
            TampilanOverlayLoading(aktif: true, pesan: pesanLoading),
        ],
      ),
      bottomNavigationBar: kantongRahasia.isNotEmpty ? TampilanTombolBungkus(
        totalItem: kantongRahasia.length,
        sedangMemproses: sedangMemproses,
        dapatAksi: dapatAksi,
        onBungkus: onBungkus,
      ) : null,
    );
  }
}
