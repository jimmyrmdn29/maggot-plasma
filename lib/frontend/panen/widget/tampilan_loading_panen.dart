import 'package:flutter/material.dart';

// ============================================================================
// TAMPILAN: OVERLAY LOADING (STATUS PROSES VERIFIKASI / BUNGKUS)
// ============================================================================
class TampilanOverlayLoading extends StatelessWidget {
  final bool aktif;
  final String pesan;

  const TampilanOverlayLoading({
    super.key,
    required this.aktif,
    required this.pesan,
  });

  @override
  Widget build(BuildContext context) {
    if (!aktif) return const SizedBox.shrink();

    return Container(
      color: Colors.black45,
      child: Center(
        child: Card(
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  pesan,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
