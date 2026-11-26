import 'package:flutter/material.dart';

// ============================================================================
// DIALOG: KONFIRMASI HAPUS MITRA (dengan spinner)
// ============================================================================
class DialogKonfirmasiHapus extends StatefulWidget {
  final String nama;
  final Future<String?> Function() onHapus;

  const DialogKonfirmasiHapus({
    super.key,
    required this.nama,
    required this.onHapus,
  });

  @override
  State<DialogKonfirmasiHapus> createState() => _DialogKonfirmasiHapusState();
}

class _DialogKonfirmasiHapusState extends State<DialogKonfirmasiHapus> {
  bool _loading = false;

  Future<void> _hapus() async {
    setState(() => _loading = true);
    final String? error = await widget.onHapus();
    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
      return;
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Data mitra ${widget.nama} berhasil dihapus."),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text("Hapus Mitra?", style: TextStyle(fontWeight: FontWeight.bold)),
      content: Text(
        "Apakah Anda yakin ingin menghapus data mitra '${widget.nama}' dari database?",
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text("BATAL", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _loading ? null : _hapus,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text("HAPUS"),
        ),
      ],
    );
  }
}
