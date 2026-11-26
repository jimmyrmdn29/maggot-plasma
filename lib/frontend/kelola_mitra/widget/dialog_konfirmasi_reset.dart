import 'package:flutter/material.dart';

// ============================================================================
// DIALOG: KONFIRMASI RESET COUNTER
// ============================================================================
class DialogKonfirmasiReset extends StatelessWidget {
  final String nama;
  final VoidCallback onConfirm;

  const DialogKonfirmasiReset({
    super.key,
    required this.nama,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Row(
        children: [
          Icon(Icons.refresh_rounded, color: Colors.blueGrey),
          SizedBox(width: 8),
          Text("Reset Counter?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
      content: Text(
        "Apakah Anda yakin ingin me-reset urutan counter tray untuk mitra '$nama' kembali ke 1?",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("BATAL", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueGrey[800],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () {
            Navigator.pop(context);
            onConfirm();
          },
          child: const Text("YA, RESET"),
        ),
      ],
    );
  }
}
