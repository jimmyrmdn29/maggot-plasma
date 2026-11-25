import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../backend/artikel/artikel_block.dart';
import '../../../backend/artikel/artikel_editor_controller.dart';
import '../../../backend/artikel/artikel_image_picker.dart';
import 'widget/cover_picker.dart';
import 'widget/editor_action_buttons.dart';
import 'widget/editor_judul_field.dart';
import 'widget/editor_konten_section.dart';

class PageEditorArtikel extends StatefulWidget {
  final String? artikelId;
  final String judulAwal;
  final String coverAwal;
  final List<ArtikelBlock> kontenAwal;

  const PageEditorArtikel({
    super.key,
    this.artikelId,
    this.judulAwal = '',
    this.coverAwal = '',
    this.kontenAwal = const <ArtikelBlock>[],
  });

  @override
  State<PageEditorArtikel> createState() => _PageEditorArtikelState();
}

class _PageEditorArtikelState extends State<PageEditorArtikel> {
  late final ArtikelEditorController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ArtikelEditorController(
      artikelId: widget.artikelId,
      judulAwal: widget.judulAwal,
      coverAwal: widget.coverAwal,
      kontenAwal: widget.kontenAwal,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final bytes = await ArtikelImagePicker.pickImageBytes();
    if (bytes == null) return;
    final bool ok = await _controller.uploadCover(bytes);
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Gagal mengupload cover."), backgroundColor: Colors.red),
    );
  }

  Future<void> _pickGambarBlok() async {
    final bytes = await ArtikelImagePicker.pickImageBytes();
    if (bytes == null) return;
    final bool ok = await _controller.tambahGambar(bytes);
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Gagal mengupload gambar."), backgroundColor: Colors.red),
    );
  }

  Future<void> _simpan() async {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sesi admin tidak ditemukan."), backgroundColor: Colors.red),
      );
      return;
    }

    final bool ok = await _controller.simpan(uid);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.artikelId == null ? "Artikel berhasil ditambahkan." : "Artikel berhasil diperbarui."),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Gagal menyimpan. Judul wajib diisi."), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.artikelId == null ? "Tambah Artikel" : "Edit Artikel"),
            backgroundColor: const Color(0xFF1A237E),
            foregroundColor: Colors.white,
            actions: [
              TextButton(
                onPressed: _controller.sedangSibuk ? null : _simpan,
                child: _controller.isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text("SIMPAN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EditorJudulField(
                  initialValue: _controller.judul,
                  onChanged: _controller.setJudul,
                ),
                const SizedBox(height: 16),
                CoverPicker(
                  coverUrl: _controller.coverUrl,
                  isUploading: _controller.isUploading,
                  onPick: _pickCover,
                  onRemove: _controller.hapusCover,
                ),
                const SizedBox(height: 16),
                EditorKontenSection(
                  blocks: _controller.blocks,
                  onTextChanged: _controller.ubahTeks,
                  onCaptionChanged: _controller.ubahCaptionGambar,
                  onDelete: _controller.hapusBlock,
                  onMoveUp: _controller.pindahAtas,
                  onMoveDown: _controller.pindahBawah,
                ),
                const SizedBox(height: 8),
                EditorActionButtons(
                  isBusy: _controller.sedangSibuk,
                  isUploading: _controller.isUploading,
                  onTambahTeks: () => _controller.tambahTeks(),
                  onTambahGambar: _pickGambarBlok,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
