import 'package:flutter/material.dart';

import '../../../backend/mitra_item.dart';
import 'tampilan_daftar_kelola_mitra.dart';
import 'tampilan_header_kelola_mitra.dart';

// ============================================================================
// TAMPILAN: HALAMAN KELOLA MITRA (PERAKIT)
// ============================================================================
class TampilanHalamanKelolaMitra extends StatelessWidget {
  final int totalMitra;
  final int totalTrayAktif;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onTambah;
  final List<MitraItem> listMitraTampil;
  final String cari;
  final void Function(String uid, String nama) onReset;
  final void Function(String uid, String nama) onHapus;

  const TampilanHalamanKelolaMitra({
    super.key,
    required this.totalMitra,
    required this.totalTrayAktif,
    required this.searchCtrl,
    required this.onSearchChanged,
    required this.onTambah,
    required this.listMitraTampil,
    required this.cari,
    required this.onReset,
    required this.onHapus,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 600;
        return Column(
          children: [
            TampilanHeaderKelolaMitra(
              totalMitra: totalMitra,
              totalTrayAktif: totalTrayAktif,
              searchCtrl: searchCtrl,
              onSearchChanged: onSearchChanged,
              onTambah: onTambah,
              isSmallScreen: isSmallScreen,
            ),
            const Divider(height: 1, thickness: 1),
            Expanded(
              child: TampilanDaftarKelolaMitra(
                listMitraTampil: listMitraTampil,
                cari: cari,
                onReset: onReset,
                onHapus: onHapus,
              ),
            ),
          ],
        );
      },
    );
  }
}
