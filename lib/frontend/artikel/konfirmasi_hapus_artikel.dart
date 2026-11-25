import 'package:flutter/material.dart';

// =========================================================================
// FUNGSI: KONFIRMASI HAPUS ARTIKEL
// =========================================================================
Future<bool> tampilkanKonfirmasiHapusArtikel(
  BuildContext context, {
  required String judul,
}) async {
  final bool? hasil = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Row(
        children: [
          Icon(Icons.delete_outline, color: Colors.red),
          SizedBox(width: 8),
          Text("Hapus Artikel?", style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: Text("Artikel \"$judul\" akan dihapus dari database."),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text("BATAL", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text("HAPUS"),
        ),
      ],
    ),
  );
  return hasil ?? false;
}
