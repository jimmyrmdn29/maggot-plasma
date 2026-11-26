import 'package:flutter/material.dart';

// ============================================================================
// TAMPILAN: HALAMAN MUAT (LOADING AWAL VERIFIKASI PANEN)
// ============================================================================
class TampilanMuatPanen extends StatelessWidget {
  final String pesan;

  const TampilanMuatPanen({
    super.key,
    required this.pesan,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(pesan),
          ],
        ),
      ),
    );
  }
}
