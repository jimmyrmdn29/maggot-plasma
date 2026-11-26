import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../backend/panen/penyimpanan_panen.dart';
import '../../backend/panen/sinkronisasi_panen.dart';
import 'widget/dialog_verifikasi_panen.dart';
import 'widget/tampilan_halaman_panen.dart';

// ============================================================================
// HALAMAN: PEMBERIAN VERIFIKASI & BUNGKUS PANEN (MENU 3)
// ============================================================================
class PageVerifikasiPanen extends StatefulWidget {
  final List<Map<String, dynamic>> daftarPanen;
  final Future<void> Function(Map<String, dynamic> paketBatch) onBungkusBatch;
  final Future<void> Function(String batchKode, List<dynamic> detailTrays) onUpdateFotoBatch;

  const PageVerifikasiPanen({
    super.key,
    required this.daftarPanen,
    required this.onBungkusBatch,
    required this.onUpdateFotoBatch,
  });

  @override
  State<PageVerifikasiPanen> createState() => _PageVerifikasiPanenState();
}

class _PageVerifikasiPanenState extends State<PageVerifikasiPanen>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  final Map<String, TextEditingController> _ctrls = {};
  List<Map<String, dynamic>> _kantongRahasia = [];
  Set<String> _trayTelahDibungkus = {};

  bool _loading = false;
  bool _isInitLoading = true;
  bool _isProcessingBungkus = false;
  String _statusPesanLoading = "Memproses...";

  late final TabController _tabController;
  final ImagePicker _picker = ImagePicker();

  final PenyimpananPanen _penyimpanan = PenyimpananPanen();
  SinkronisasiPanen? _sinkronisasi;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _sinkronisasi = SinkronisasiPanen(onUpdateFotoBatch: widget.onUpdateFotoBatch);
    _muatDataLokal();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sinkronisasi?.jalankanProsesSync();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (var c in _ctrls.values) {
      c.dispose();
    }
    _ctrls.clear();
    super.dispose();
  }

  // ==========================================================
  // MANAJEMEN PENYIMPANAN LOCAL
  // ==========================================================
  Future<void> _muatDataLokal() async {
    try {
      _trayTelahDibungkus = await _penyimpanan.muatTrayDibungkus();
      _kantongRahasia = await _penyimpanan.muatDraft();
    } catch (e) {
      debugPrint("Gagal membaca storage lokal: $e");
    } finally {
      if (mounted) setState(() => _isInitLoading = false);
    }
  }

  List<Map<String, dynamic>> get _antreanAktif {
    final Set<String> namaDiKantong = _kantongRahasia.map((e) => e['nama'].toString()).toSet();

    return widget.daftarPanen.where((item) {
      final String nama = item['nama'].toString();
      final bool sudahDiKantong = namaDiKantong.contains(nama);
      final bool sudahDibungkus = _trayTelahDibungkus.contains(nama);
      return !sudahDiKantong && !sudahDibungkus;
    }).toList();
  }

  TextEditingController _getController(String key) {
    return _ctrls.putIfAbsent(key, () => TextEditingController());
  }

  // ==========================================================
  // KONEKSI & GPS DENGAN PROTEKSI FAKE GPS
  // ==========================================================
  Future<bool> _pastikanGpsAktif() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) _tampilkanDialogGpsMati();
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackbar("Izin lokasi ditolak! GPS wajib aktif untuk verifikasi.", isError: true);
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) _tampilkanDialogIzinPermanen();
      return false;
    }

    return true;
  }

  void _tampilkanDialogGpsMati() {
    DialogVerifikasiPanen.tampilkanDialogGpsMati(context);
  }

  void _tampilkanDialogIzinPermanen() {
    DialogVerifikasiPanen.tampilkanDialogIzinPermanen(context);
  }

  void _tampilkanDialogFakeGps() {
    DialogVerifikasiPanen.tampilkanDialogFakeGps(context);
  }

  Future<Position?> _getFastLocation() async {
    try {
      Position? lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) return lastKnown;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (_) {
      return null;
    }
  }

  Future<File> _simpanFotoLokal(XFile foto) async {
    final Directory docDir = await getApplicationDocumentsDirectory();
    final String fileName = "panen_${DateTime.now().millisecondsSinceEpoch}.jpg";
    return await File(foto.path).copy('${docDir.path}/$fileName');
  }

  // ==========================================================
  // VERIFIKASI TRAY
  // ==========================================================
  Future<void> _verifikasi(Map<String, dynamic> data) async {
    // 1. Anti Double-Click / Race Condition Protection
    if (_loading || _isProcessingBungkus) return;

    final String trayName = data['nama']?.toString() ?? 'Tray';
    final bool isGagal = data['status'] == "GAGAL";
    final ctrl = _getController(trayName);

    // 2. Validasi Desimal Angka
    if (!isGagal) {
      final cleanText = ctrl.text.trim().replaceAll(',', '.');
      final double? beratVal = double.tryParse(cleanText);
      if (cleanText.isEmpty || beratVal == null) {
        _showSnackbar("Isi berat hasil panen $trayName dengan angka yang valid!", isError: true);
        return;
      }
    }

    final bool gpsSiap = await _pastikanGpsAktif();
    if (!gpsSiap) return;

    final gpsFuture = _getFastLocation();

    final XFile? foto = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1280,
      maxHeight: 1280,
    );

    if (foto == null) return;

    setState(() {
      _loading = true;
      _statusPesanLoading = "Memvalidasi GPS & menyimpan foto...";
    });

    try {
      final Position? pos = await gpsFuture;

      // 3. Validasi Keamanan Satelit Anti-Fake GPS
      if (pos != null && pos.isMocked) {
        setState(() => _loading = false);
        _tampilkanDialogFakeGps();
        return;
      }

      final String koordinatGps = (pos != null)
          ? "${pos.latitude.toStringAsFixed(6)},${pos.longitude.toStringAsFixed(6)}"
          : "-6.200000,106.816666";

      final File localFile = await _simpanFotoLokal(foto);

      String tglMulaiFormatted = "-";
      if (data['tanggalMulai'] != null) {
        var tgl = data['tanggalMulai'];
        DateTime dt = (tgl is Timestamp) ? tgl.toDate() : (tgl is DateTime ? tgl : DateTime.now());
        tglMulaiFormatted = DateFormat('dd/MM/yyyy').format(dt);
      }

      final itemBaru = {
        "nama": trayName,
        "hasilKg": isGagal ? "0" : ctrl.text.trim().replaceAll(',', '.'),
        "status": isGagal ? "GAGAL" : "BERHASIL",
        "gps": koordinatGps,
        "tanggalPanen": DateFormat('dd/MM/yyyy').format(DateTime.now()),
        "waktuVerifikasi": DateTime.now().toIso8601String(),
        "beratTelur": (data['beratTelur'] ?? "0").toString(),
        "tglMulaiFormatted": tglMulaiFormatted,
        "fotoLocalPath": localFile.path,
        "fotoBase64": "",
        "fotoUrl": "",
      };

      setState(() {
        _kantongRahasia.add(itemBaru);
        ctrl.clear();
      });

      await _penyimpanan.simpanDraft(_kantongRahasia);
      _showSnackbar("✅ $trayName berhasil diverifikasi.");
    } catch (e) {
      _showSnackbar("Gagal: $e", isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _batalkanDariKantong(int index) async {
    final item = _kantongRahasia[index];
    try {
      final localPath = item['fotoLocalPath'];
      if (localPath != null) {
        final f = File(localPath);
        if (await f.exists()) await f.delete();
      }
    } catch (_) {}

    setState(() {
      _kantongRahasia.removeAt(index);
    });
    await _penyimpanan.simpanDraft(_kantongRahasia);
    _showSnackbar("${item['nama']} dikembalikan ke antrean.");
  }

  // ==========================================================
  // BUNGKUS BATCH & SINKRONISASI
  // ==========================================================
  Future<void> _prosesBungkusInstan() async {
    if (_isProcessingBungkus || _loading || _kantongRahasia.isEmpty) return;

    setState(() {
      _isProcessingBungkus = true;
      _loading = true;
      _statusPesanLoading = "Membungkus data panen...";
    });

    try {
      final User? userMitra = FirebaseAuth.instance.currentUser;
      final prefs = await SharedPreferences.getInstance();

      final String uidMitra = userMitra?.uid ?? prefs.getString('mitra_uid') ?? 'UID_UNKNOWN';
      final String namaMitra = prefs.getString('mitra_nama') ?? userMitra?.displayName ?? userMitra?.email ?? 'Mitra Lapangan';
      final String emailMitra = userMitra?.email ?? prefs.getString('mitra_email') ?? '-';

      double totalKg = 0.0;
      for (var item in _kantongRahasia) {
        totalKg += double.tryParse(item['hasilKg']?.toString() ?? '0') ?? 0.0;
      }

      final now = DateTime.now();
      final String batchKode = "BATCH-${DateFormat('ddMMyy-HHmmss').format(now)}";

      final Map<String, dynamic> paketBatch = {
        "batchKode": batchKode,
        "tanggalBungkus": Timestamp.fromDate(now),
        "tanggalFormatted": DateFormat('dd/MM/yyyy HH:mm').format(now),
        "totalBeratKg": double.parse(totalKg.toStringAsFixed(2)),
        "jumlahTray": _kantongRahasia.length,
        "status": "TERBUNGKUS",
        "statusVerifikasiAdmin": "MENUNGGU_REVIEW",
        "sumberPintu": "MITRA_APP",
        "mitraId": uidMitra,
        "mitraNama": namaMitra,
        "mitraEmail": emailMitra,
        "detailTrays": List<Map<String, dynamic>>.from(_kantongRahasia),
      };

      for (var item in _kantongRahasia) {
        _trayTelahDibungkus.add(item['nama'].toString());
      }
      await _penyimpanan.simpanTrayDibungkus(_trayTelahDibungkus.toList());

      await widget.onBungkusBatch(paketBatch);

      final List<String> queue = await _penyimpanan.muatAntreanSync();
      queue.add(jsonEncode(paketBatch, toEncodable: PenyimpananPanen.customJsonSerializer));
      await _penyimpanan.simpanAntreanSync(queue);

      _kantongRahasia.clear();
      await _penyimpanan.hapusDraft();

      _tabController.animateTo(0);
      _showSnackbar("🎉 $batchKode Berhasil Dibungkus! Tersimpan di Menu 4.", isError: false);

      _sinkronisasi?.jalankanProsesSync();
    } catch (e) {
      _showSnackbar("Terjadi kesalahan saat membungkus: $e", isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _isProcessingBungkus = false;
        });
      }
    }
  }

  void _showSnackbar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red[800] : Colors.green[800],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ==========================================================
  // USER INTERFACE
  // ==========================================================
  @override
  Widget build(BuildContext context) {
    super.build(context);

    return TampilanHalamanPanen(
      antrean: _antreanAktif,
      kantong: _kantongRahasia,
      sedangMemproses: _isProcessingBungkus,
      dapatAksi: !_loading && !_isProcessingBungkus,
      sedangMuat: _isInitLoading,
      pesanMuat: "Memuat data panen...",
      tabController: _tabController,
      controller: _getController,
      onVerifikasi: (Map<String, dynamic> data) => _verifikasi(data),
      onBatalkan: (int index) => _batalkanDariKantong(index),
      onBungkus: () => _prosesBungkusInstan(),
      sedangLoading: _loading,
      pesanLoading: _statusPesanLoading,
    );
  }
}
