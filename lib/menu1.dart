// menu1.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// =========================================================================
// 1. MODEL DATA (Mencegah Salah Ketik Key JSON / Map)
// =========================================================================
class _TrayItem {
  final String beratTelur;
  final Timestamp tanggalMulai;
  final String tanggalTampil;

  const _TrayItem({
    required this.beratTelur,
    required this.tanggalMulai,
    required this.tanggalTampil,
  });

  // Untuk dikirim ke Firestore / Callback
  Map<String, dynamic> toFirestoreMap() {
    return {
      "beratTelur": beratTelur,
      "tanggalMulai": tanggalMulai,
      "tanggalTampil": tanggalTampil,
    };
  }

  // Untuk disimpan ke Local Storage (SharedPreferences)
  Map<String, dynamic> toStorageMap() {
    return {
      "beratTelur": beratTelur,
      "tanggalMulaiMs": tanggalMulai.millisecondsSinceEpoch,
      "tanggalTampil": tanggalTampil,
    };
  }

  // Untuk dimuat dari Local Storage
  factory _TrayItem.fromStorageMap(Map<String, dynamic> map) {
    return _TrayItem(
      beratTelur: map["beratTelur"] ?? "0",
      tanggalMulai: Timestamp.fromMillisecondsSinceEpoch(map["tanggalMulaiMs"] ?? 0),
      tanggalTampil: map["tanggalTampil"] ?? "-",
    );
  }
}

// =========================================================================
// 2. SERVICE LOCAL STORAGE (Menangani Draft Tanpa Mengotori UI)
// =========================================================================
class _DraftTrayStorage {
  static const String _storageKey = 'draft_antrean_tray';

  static Future<List<_TrayItem>> loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? draftJson = prefs.getString(_storageKey);
      if (draftJson == null || draftJson.isEmpty) return [];

      final List<dynamic> decoded = json.decode(draftJson);
      return decoded.map((item) => _TrayItem.fromStorageMap(item)).toList();
    } catch (e) {
      debugPrint("Gagal memuat draft tray: $e");
      return [];
    }
  }

  static Future<void> saveDraft(List<_TrayItem> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> toSave = list.map((e) => e.toStorageMap()).toList();
      await prefs.setString(_storageKey, json.encode(toSave));
    } catch (_) {}
  }

  static Future<void> clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (_) {}
  }
}

// =========================================================================
// 3. WIDGET UTAMA (MENU SATU)
// =========================================================================
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
  final TextEditingController _beratCtrl = TextEditingController();
  final List<_TrayItem> _antreanTray = [];
  
  DateTime _tglTerpilih = DateTime.now();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _inisialisasiDraft();
  }

  @override
  void dispose() {
    _beratCtrl.dispose();
    super.dispose();
  }

  Future<void> _inisialisasiDraft() async {
    final list = await _DraftTrayStorage.loadDraft();
    if (mounted) {
      setState(() {
        _antreanTray.clear();
        _antreanTray.addAll(list);
      });
    }
  }

  // --- AKSI PENGGUNA ---

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

  void _tambahKeDaftar() {
    final String beratText = _beratCtrl.text.trim();
    if (beratText.isEmpty) {
      _showSnackbar("Isi berat telur dulu sebelum ditambah ke daftar!", isError: true);
      return;
    }

    setState(() {
      _antreanTray.add(
        _TrayItem(
          beratTelur: beratText,
          tanggalMulai: Timestamp.fromDate(_tglTerpilih),
          tanggalTampil: DateFormat('dd MMM yyyy').format(_tglTerpilih),
        ),
      );
      _beratCtrl.clear();
    });

    _DraftTrayStorage.saveDraft(_antreanTray);
    FocusScope.of(context).unfocus();
  }

  void _hapusDariDaftar(int index) {
    setState(() {
      _antreanTray.removeAt(index);
    });
    _DraftTrayStorage.saveDraft(_antreanTray);
  }

  Future<void> _simpanSemuaData() async {
    if (_isSubmitting) return;
    if (_antreanTray.isEmpty) {
      _showSnackbar("Belum ada tray di daftar. Tambah dulu minimal 1.", isWarning: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Konversi Model ke format Map asli yang diharapkan oleh callback luar
      final List<Map<String, dynamic>> payload = _antreanTray.map((e) => e.toFirestoreMap()).toList();
      await widget.onTambahBanyakData(payload);

      if (mounted) {
        final int jumlah = _antreanTray.length;
        setState(() => _antreanTray.clear());
        await _DraftTrayStorage.clearDraft();

        _showSnackbar("✅ $jumlah Tray Berhasil Disimpan!");
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar("Gagal menyimpan data: $e", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnackbar(String pesan, {bool isError = false, bool isWarning = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();

    Color bgColor = Colors.green;
    if (isError) bgColor = Colors.red;
    if (isWarning) bgColor = Colors.orange;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(pesan),
        backgroundColor: bgColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ==========================================================
  // USER INTERFACE
  // ==========================================================
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
            _buildDatePickerBox(),
            const SizedBox(height: 20),

            _buildInputBeratRow(),
            const SizedBox(height: 24),

            if (_antreanTray.isNotEmpty) ...[
              _buildListAntreanHeader(),
              const SizedBox(height: 10),
              _buildListAntrean(),
              const SizedBox(height: 20),
            ],

            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePickerBox() {
    return InkWell(
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
    );
  }

  Widget _buildInputBeratRow() {
    return Row(
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
    );
  }

  Widget _buildListAntreanHeader() {
    return Text(
      "Daftar Tray Siap Disimpan (${_antreanTray.length})",
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildListAntrean() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _antreanTray.length,
      itemBuilder: (context, index) {
        final item = _antreanTray[index];
        final int nomorTray = widget.nomorTrayOtomatis + index;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green[100],
              child: Text(
                "$nomorTray",
                style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            title: Text("${item.beratTelur} gram"),
            subtitle: Text(item.tanggalTampil),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _isSubmitting ? null : () => _hapusDariDaftar(index),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubmitButton() {
    final bool isDisabled = _isSubmitting || _antreanTray.isEmpty;

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isDisabled ? Colors.grey : Colors.green,
          foregroundColor: Colors.white,
        ),
        onPressed: isDisabled ? null : _simpanSemuaData,
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