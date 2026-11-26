import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../backend/auth/pembuat_akun_mitra_admin.dart';
import '../../backend/mitra/penyimpanan_mitra.dart';
import 'widget/dialog_konfirmasi_hapus.dart';
import 'widget/dialog_konfirmasi_reset.dart';
import 'widget/dialog_tambah_mitra.dart';
import 'widget/tampilan_halaman_kelola_mitra.dart';

// =============================================================================
// MAIN WIDGET: PAGE KELOLA MITRA
// =============================================================================
class PageKelolaMitra extends StatefulWidget {
  const PageKelolaMitra({super.key});

  @override
  State<PageKelolaMitra> createState() => _PageKelolaMitraState();
}

class _PageKelolaMitraState extends State<PageKelolaMitra> {
  final TextEditingController _namaCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();

  String _cari = "";
  Timer? _debounceTimer;
  final PenyimpananMitra _penyimpanan = PenyimpananMitra();

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _namaCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // =========================================================================
  // PENCARIAN DENGAN DEBOUNCE
  // =========================================================================
  void _onSearchChanged(String value) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() {
          _cari = value.trim().toLowerCase();
        });
      }
    });
  }

  // =========================================================================
  // TAMBAH MITRA
  // =========================================================================
  Future<String?> _prosesTambahMitra() async {
    final String nama = _namaCtrl.text.trim();
    final String email = _emailCtrl.text.trim();
    final String pass = _passCtrl.text.trim();

    if (nama.isEmpty || email.isEmpty || pass.isEmpty) {
      return "Lengkapi semua data!";
    }

    // Pakai fungsi yang SUDAH cek role admin di Firestore sebelum bikin akun
    final String? error = await PembuatAkunMitraAdmin().adminBuatAkunMitra(email, pass, nama);

    if (error == null) {
      _namaCtrl.clear();
      _emailCtrl.clear();
      _passCtrl.clear();
    }
    return error;
  }

  void _showTambahDialog() {
    showDialog(
      context: context,
      builder: (context) => DialogTambahMitra(
        namaCtrl: _namaCtrl,
        emailCtrl: _emailCtrl,
        passCtrl: _passCtrl,
        onSimpan: _prosesTambahMitra,
      ),
    );
  }

  // =========================================================================
  // RESET COUNTER
  // =========================================================================
  void _konfirmasiResetCounter(String uid, String nama) {
    showDialog(
      context: context,
      builder: (ctx) => DialogKonfirmasiReset(
        nama: nama,
        onConfirm: () => _eksekusiResetCounter(uid, nama),
      ),
    );
  }

  Future<void> _eksekusiResetCounter(String uid, String nama) async {
    try {
      await _penyimpanan.resetCounterTray(uid);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Counter tray $nama berhasil direset ke 1"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Gagal reset counter: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // =========================================================================
  // HAPUS MITRA
  // =========================================================================
  Future<String?> _prosesHapusMitra(String uid, String nama) async {
    try {
      await _penyimpanan.hapusMitra(uid, nama);
      return null;
    } catch (e) {
      return "Gagal menghapus: $e";
    }
  }

  void _konfirmasiHapus(String uid, String nama) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DialogKonfirmasiHapus(
        nama: nama,
        onHapus: () => _prosesHapusMitra(uid, nama),
      ),
    );
  }

  // =========================================================================
  // UI
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _penyimpanan.streamSemuaUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text("Terjadi kesalahan: ${snapshot.error}"));
        }

        final semuaMitra = PenyimpananMitra.parseDaftarMitra(snapshot.data?.docs ?? []);

        final int totalMitra = semuaMitra.length;

        int totalTrayAktif = 0;
        for (var mitra in semuaMitra) {
          totalTrayAktif += mitra.siklus.length;
        }

        final listMitraTampil = semuaMitra
            .where((mitra) => mitra.nama.toLowerCase().contains(_cari))
            .toList();

        return TampilanHalamanKelolaMitra(
          totalMitra: totalMitra,
          totalTrayAktif: totalTrayAktif,
          searchCtrl: _searchCtrl,
          onSearchChanged: _onSearchChanged,
          onTambah: _showTambahDialog,
          listMitraTampil: listMitraTampil,
          cari: _cari,
          onReset: _konfirmasiResetCounter,
          onHapus: _konfirmasiHapus,
        );
      },
    );
  }
}
