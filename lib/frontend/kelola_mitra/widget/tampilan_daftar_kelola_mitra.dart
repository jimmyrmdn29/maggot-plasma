import 'package:flutter/material.dart';

import '../../../backend/mitra_item.dart';
import 'tampilan_kartu_mitra.dart';

// ============================================================================
// TAMPILAN: DAFTAR MITRA (EMPTY STATE + GRID)
// ============================================================================
class TampilanDaftarKelolaMitra extends StatelessWidget {
  final List<MitraItem> listMitraTampil;
  final String cari;
  final void Function(String uid, String nama) onReset;
  final void Function(String uid, String nama) onHapus;

  const TampilanDaftarKelolaMitra({
    super.key,
    required this.listMitraTampil,
    required this.cari,
    required this.onReset,
    required this.onHapus,
  });

  @override
  Widget build(BuildContext context) {
    if (listMitraTampil.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off_outlined, size: 50, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              cari.isEmpty ? "Belum ada mitra terdaftar" : "Mitra '$cari' tidak ditemukan",
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 360,
        mainAxisExtent: 145,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: listMitraTampil.length,
      itemBuilder: (ctx, i) {
        final mitra = listMitraTampil[i];
        return TampilanKartuMitra(
          mitra: mitra,
          onReset: () => onReset(mitra.uid, mitra.nama),
          onHapus: () => onHapus(mitra.uid, mitra.nama),
        );
      },
    );
  }
}
