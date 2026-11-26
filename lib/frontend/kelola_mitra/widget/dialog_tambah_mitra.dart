import 'package:flutter/material.dart';

// ============================================================================
// DIALOG: TAMBAH MITRA BARU
// ============================================================================
class DialogTambahMitra extends StatefulWidget {
  final TextEditingController namaCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final Future<String?> Function() onSimpan;

  const DialogTambahMitra({
    super.key,
    required this.namaCtrl,
    required this.emailCtrl,
    required this.passCtrl,
    required this.onSimpan,
  });

  @override
  State<DialogTambahMitra> createState() => _DialogTambahMitraState();
}

class _DialogTambahMitraState extends State<DialogTambahMitra> {
  bool _loading = false;

  Future<void> _simpan() async {
    setState(() => _loading = true);
    final String? error = await widget.onSimpan();
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
      const SnackBar(
        content: Text("Mitra Baru Berhasil Ditambahkan"),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text("Tambah Mitra Baru", style: TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: widget.namaCtrl,
              decoration: const InputDecoration(
                labelText: "Nama Lengkap",
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: widget.emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: "Email",
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: widget.passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Password Default",
                prefixIcon: Icon(Icons.lock),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text("Batal", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[800],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _loading ? null : _simpan,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text("SIMPAN"),
        ),
      ],
    );
  }
}
