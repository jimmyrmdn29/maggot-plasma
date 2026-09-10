//menu1.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class MenuSatu extends StatefulWidget {
  final int nomorTrayOtomatis;
  final String namaMitra; // Ambil dari data login
  final Function(Map<String, dynamic>) onTambahData;

  const MenuSatu({
    super.key,
    required this.nomorTrayOtomatis,
    required this.namaMitra,
    required this.onTambahData,
  });

  @override
  State<MenuSatu> createState() => _MenuSatuState();
}

class _MenuSatuState extends State<MenuSatu> {
  final _beratCtrl = TextEditingController();
  DateTime _tglTerpilih = DateTime.now();
  bool _isSubmitting = false; // 🔒 Pengunci untuk cegah spam klik

  @override
  void dispose() {
    _beratCtrl.dispose();
    super.dispose();
  }

  // Fungsi Pilih Tanggal dengan Batasan
  Future<void> _pilihTanggal(BuildContext context) async {
    // Tutup keyboard terlebih dahulu jika terbuka
    FocusScope.of(context).unfocus();

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _tglTerpilih,
      // Batasi: Paling lama 21 hari ke belakang dari hari ini
      firstDate: DateTime.now().subtract(const Duration(days: 21)),
      // Batasi: Tidak bisa pilih tanggal di masa depan
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _tglTerpilih) {
      setState(() {
        _tglTerpilih = picked;
      });
    }
  }

  // Logika Simpan Data Aman Anti-Spam
  Future<void> _simpanData() async {
    // 1. Kunci seketika jika sedang diproses
    if (_isSubmitting) return;

    final String beratText = _beratCtrl.text.trim();
    if (beratText.isEmpty) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Isi berat telur terlebih dahulu!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 2. Aktifkan pengunci & ubah tampilan tombol
    setState(() {
      _isSubmitting = true;
    });

    FocusScope.of(context).unfocus();

    try {
      // 3. Panggil callback simpan data
      await widget.onTambahData({
        "peternak": widget.namaMitra,
        "nama": "Tray ${widget.nomorTrayOtomatis}",
        "beratTelur": beratText,
        "tanggalMulai": Timestamp.fromDate(_tglTerpilih),
        "cekM1": null,
        "cekM2": null,
      });

      _beratCtrl.clear();
      
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Data Berhasil Disimpan!"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal menyimpan data: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // 4. Buka kembali kunci setelah selesai
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
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
            
            // Info Mitra (Otomatis)
            _buildReadOnlyField("Nama Mitra", widget.namaMitra),
            _buildReadOnlyField("Nomor Tray", "Tray ${widget.nomorTrayOtomatis}"),

            // Pilih Tanggal
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

            // Input Berat Telur
            TextField(
              controller: _beratCtrl,
              enabled: !_isSubmitting, // Disable input saat proses simpan
              decoration: const InputDecoration(
                labelText: "Berat Telur (Gram)",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.scale),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isSubmitting ? Colors.grey : Colors.green,
                  foregroundColor: Colors.white,
                ),
                // 🔒 Disable tombol otomatis jika _isSubmitting bernilai true
                onPressed: _isSubmitting ? null : _simpanData,
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
                    : const Text("SIMPAN DATA", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            )
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