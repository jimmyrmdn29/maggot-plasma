// menu1.dart
import 'dart:convert'; // Tambahan untuk encode/decode JSON
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Tambahan package

class MenuSatu extends StatefulWidget {
  final int nomorTrayOtomatis;
  final String namaMitra;
  final Future<void> Function(List<Map<String, dynamic>>) onTambahBanyakData;

  const MenuSatu({
    super.key,
    required this.nomorTrayOtomatis,
    required this.namaMitra,
    required this.onTambahBanyakData,
  });

  @override
  State<MenuSatu> createState() => _MenuSatuState();
}

class _MenuSatuState extends State<MenuSatu> {
  final _beratCtrl = TextEditingController();
  DateTime _tglTerpilih = DateTime.now();
  bool _isSubmitting = false;

  // Key untuk SharedPreferences
  static const String _draftKey = 'draft_antrean_tray';

  // Daftar tray yang mau disimpan
  final List<Map<String, dynamic>> _antreanTray = [];

  @override
  void initState() {
    super.initState();
    _loadDraft(); // Load data yang belum tersimpan saat buka menu ini
  }

  @override
  void dispose() {
    _beratCtrl.dispose();
    super.dispose();
  }

  // --- FUNGSI LOCAL STORAGE (DRAFT) ---

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final String? draftJson = prefs.getString(_draftKey);

    if (draftJson != null) {
      final List<dynamic> decoded = json.decode(draftJson);
      setState(() {
        _antreanTray.clear();
        for (var item in decoded) {
          _antreanTray.add({
            "beratTelur": item["beratTelur"],
            // Firestore Timestamp tidak bisa di-JSON-kan langsung, jadi kita load dari int (milliseconds)
            "tanggalMulai": Timestamp.fromMillisecondsSinceEpoch(item["tanggalMulaiMs"]),
            "tanggalTampil": item["tanggalTampil"],
          });
        }
      });
    }
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    // Ubah Timestamp menjadi int agar bisa di-encode ke JSON
    final List<Map<String, dynamic>> toSave = _antreanTray.map((item) {
      return {
        "beratTelur": item["beratTelur"],
        "tanggalMulaiMs": (item["tanggalMulai"] as Timestamp).millisecondsSinceEpoch,
        "tanggalTampil": item["tanggalTampil"],
      };
    }).toList();

    await prefs.setString(_draftKey, json.encode(toSave));
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  // --- END LOCAL STORAGE ---

  Future<void> _pilihTanggal(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _tglTerpilih,
      firstDate: DateTime.now().subtract(const Duration(days: 21)),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _tglTerpilih) {
      setState(() => _tglTerpilih = picked);
    }
  }

  // Nambah 1 tray ke daftar LOKAL
  void _tambahKeDaftar() {
    final String beratText = _beratCtrl.text.trim();
    if (beratText.isEmpty) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Isi berat telur dulu sebelum ditambah ke daftar!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _antreanTray.add({
        "beratTelur": beratText,
        "tanggalMulai": Timestamp.fromDate(_tglTerpilih),
        "tanggalTampil": DateFormat('dd MMM yyyy').format(_tglTerpilih),
      });
      _beratCtrl.clear();
    });
    
    _saveDraft(); // Simpan ke local storage setiap kali ada penambahan data
    FocusScope.of(context).unfocus();
  }

  void _hapusDariDaftar(int index) {
    setState(() {
      _antreanTray.removeAt(index);
    });
    _saveDraft(); // Update local storage saat data dihapus
  }

  // Kirim SEMUA tray ke Firestore SEKALIGUS
  Future<void> _simpanSemuaData() async {
    if (_isSubmitting) return;
    if (_antreanTray.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Belum ada tray di daftar. Tambah dulu minimal 1."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await widget.onTambahBanyakData(_antreanTray);

      // Jika berhasil simpan ke Firestore, hapus antrean dan bersihkan Draf lokal
      if (mounted) {
        final int jumlah = _antreanTray.length;
        setState(() => _antreanTray.clear());
        await _clearDraft(); // Hapus draf lokal karena sudah aman di Firestore

        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ $jumlah Tray Berhasil Disimpan!"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal menyimpan data: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Detail Input Telur", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            _buildReadOnlyField("Nama Mitra", widget.namaMitra),
            _buildReadOnlyField(
              "Tray Akan Dimulai Dari",
              "Tray ${widget.nomorTrayOtomatis}"
              "${_antreanTray.length > 1 ? ' — Tray ${widget.nomorTrayOtomatis + _antreanTray.length - 1}' : ''}",
            ),

            const Text("Tanggal Telur Mulai", style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 8),
            InkWell(
              onTap: _isSubmitting ? null : () => _pilihTanggal(context),
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(DateFormat('dd MMMM yyyy').format(_tglTerpilih)),
                    const Icon(Icons.calendar_month, color: Colors.green),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _beratCtrl,
                    enabled: !_isSubmitting,
                    decoration: const InputDecoration(
                      labelText: "Berat Telur (Gram)",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.scale),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onSubmitted: (_) => _tambahKeDaftar(),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onPressed: _isSubmitting ? null : _tambahKeDaftar,
                    child: const Icon(Icons.add),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (_antreanTray.isNotEmpty) ...[
              Text(
                "Daftar Tray Siap Disimpan (${_antreanTray.length})",
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _antreanTray.length,
                itemBuilder: (context, index) {
                  final item = _antreanTray[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.green[100],
                        child: Text("${widget.nomorTrayOtomatis + index}",
                            style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      title: Text("${item['beratTelur']} gram"),
                      subtitle: Text(item['tanggalTampil']),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: _isSubmitting ? null : () => _hapusDariDaftar(index),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isSubmitting || _antreanTray.isEmpty ? Colors.grey : Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: (_isSubmitting || _antreanTray.isEmpty) ? null : _simpanSemuaData,
                child: _isSubmitting
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text("MENYIMPAN...", style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      )
                    : Text(
                        _antreanTray.isEmpty
                            ? "SIMPAN DATA"
                            : "SIMPAN SEMUA (${_antreanTray.length} Tray)",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const Divider(),
        ],
      ),
    );
  }
}