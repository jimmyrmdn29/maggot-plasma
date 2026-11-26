import 'package:flutter/material.dart';

// ============================================================================
// TAMPILAN: TOMBOL BUNGKUS BATCH (KANTONG PANEN)
// ============================================================================
class TampilanTombolBungkus extends StatelessWidget {
  final int totalItem;
  final bool sedangMemproses;
  final bool dapatAksi;
  final Future<void> Function() onBungkus;

  const TampilanTombolBungkus({
    super.key,
    required this.totalItem,
    required this.sedangMemproses,
    required this.dapatAksi,
    required this.onBungkus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -3))],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: sedangMemproses ? Colors.grey : Colors.orange[800],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 2,
            ),
            onPressed: dapatAksi ? onBungkus : null,
            icon: const Icon(Icons.inventory_2_rounded),
            label: Text(
              sedangMemproses ? "MEMBUNGKUS..." : "BUNGKUS $totalItem TRAY SELESAI",
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}
