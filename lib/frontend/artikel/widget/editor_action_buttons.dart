import 'package:flutter/material.dart';

// =========================================================================
// WIDGET: TOMBOL AKSI EDITOR
// =========================================================================
class EditorActionButtons extends StatelessWidget {
  final bool isBusy;
  final bool isUploading;
  final VoidCallback onTambahTeks;
  final VoidCallback onTambahGambar;

  const EditorActionButtons({
    super.key,
    required this.isBusy,
    required this.isUploading,
    required this.onTambahTeks,
    required this.onTambahGambar,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.notes),
            label: const Text("Tambah Teks"),
            onPressed: isBusy ? null : onTambahTeks,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            icon: isUploading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.image_outlined),
            label: Text(isUploading ? "Mengupload..." : "Tambah Gambar"),
            onPressed: isBusy ? null : onTambahGambar,
          ),
        ),
      ],
    );
  }
}
