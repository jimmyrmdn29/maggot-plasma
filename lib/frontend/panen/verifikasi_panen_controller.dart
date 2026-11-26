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

// ============================================================================
// VIEWMODEL: VERIFIKASI & BUNGKUS PANEN (state + flow, tanpa widget)
// ============================================================================
class VerifikasiPanenController extends ChangeNotifier {
  VerifikasiPanenController({
    required this.daftarPanen,
    required this.onBungkusBatch,
    required this.onUpdateFotoBatch,
    required this.isMounted,
    required this.onSnackbar,
    required this.onBungkusSelesai,
    required this.onGpsMati,
    required this.onIzinPermanen,
    required this.onFakeGps,
  }) {
    _sinkronisasi = SinkronisasiPanen(onUpdateFotoBatch: onUpdateFotoBatch);
    _muatDataLokal();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sinkronisasi?.jalankanProsesSync();
    });
  }

  final List<Map<String, dynamic>> daftarPanen;
  final Future<void> Function(Map<String, dynamic> paketBatch) onBungkusBatch;
  final Future<void> Function(String batchKode, List<dynamic> detailTrays) onUpdateFotoBatch;
  final bool Function() isMounted;
  final void Function(String msg, {bool isError}) onSnackbar;
  final void Function() onBungkusSelesai;
  final void Function() onGpsMati;
  final void Function() onIzinPermanen;
  final void Function() onFakeGps;

  final Map<String, TextEditingController> _ctrls = {};
  List<Map<String, dynamic>> _kantongRahasia = [];
  Set<String> _trayTelahDibungkus = {};

  bool _loading = false;
  bool _isInitLoading = true;
  bool _isProcessingBungkus = false;
  String _statusPesanLoading = "Memproses...";

  final ImagePicker _picker = ImagePicker();

  final PenyimpananPanen _penyimpanan = PenyimpananPanen();
  SinkronisasiPanen? _sinkronisasi;

  // ---------- getters ----------
  List<Map<String, dynamic>> get kantongRahasia => _kantongRahasia;
  Set<String> get trayTelahDibungkus => _trayTelahDibungkus;
  bool get loading => _loading;
  bool get isInitLoading => _isInitLoading;
  bool get isProcessingBungkus => _isProcessingBungkus;
  String get statusPesanLoading => _statusPesanLoading;

  List<Map<String, dynamic>> get antreanAktif {
    final Set<String> namaDiKantong = _kantongRahasia.map((e) => e['nama'].toString()).toSet();

    return daftarPanen.where((item) {
      final String nama = item['nama'].toString();
      final bool sudahDiKantong = namaDiKantong.contains(nama);
      final bool sudahDibungkus = _trayTelahDibungkus.contains(nama);
      return !sudahDiKantong && !sudahDibungkus;
    }).toList();
  }

  bool get dapatAksi => !_loading && !_isProcessingBungkus;

  TextEditingController getController(String key) {
    return _ctrls.putIfAbsent(key, () => TextEditingController());
  }

  // ---------- local storage ----------
  Future<void> _muatDataLokal() async {
    try {
      _trayTelahDibungkus = await _penyimpanan.muatTrayDibungkus();
      _kantongRahasia = await _penyimpanan.muatDraft();
    } catch (e) {
      debugPrint("Gagal membaca storage lokal: $e");
    } finally {
      if (isMounted()) {
        _isInitLoading = false;
        notifyListeners();
      }
    }
  }

  // ---------- gps ----------
  Future<bool> pastikanGpsAktif() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      onGpsMati();
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        onSnackbar("Izin lokasi ditolak! GPS wajib aktif untuk verifikasi.", isError: true);
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      onIzinPermanen();
      return false;
    }

    return true;
  }

  Future<Position?> getFastLocation() async {
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

  Future<File> simpanFotoLokal(XFile foto) async {
    final Directory docDir = await getApplicationDocumentsDirectory();
    final String fileName = "panen_${DateTime.now().millisecondsSinceEpoch}.jpg";
    return await File(foto.path).copy('${docDir.path}/$fileName');
  }

  // ---------- verifikasi ----------
  Future<void> verifikasi(Map<String, dynamic> data) async {
    if (_loading || _isProcessingBungkus) return;

    final String trayName = data['nama']?.toString() ?? 'Tray';
    final bool isGagal = data['status'] == "GAGAL";
    final ctrl = getController(trayName);

    if (!isGagal) {
      final cleanText = ctrl.text.trim().replaceAll(',', '.');
      final double? beratVal = double.tryParse(cleanText);
      if (cleanText.isEmpty || beratVal == null) {
        onSnackbar("Isi berat hasil panen $trayName dengan angka yang valid!", isError: true);
        return;
      }
    }

    final bool gpsSiap = await pastikanGpsAktif();
    if (!gpsSiap) return;

    final gpsFuture = getFastLocation();

    final XFile? foto = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1280,
      maxHeight: 1280,
    );

    if (foto == null) return;

    _loading = true;
    _statusPesanLoading = "Memvalidasi GPS & menyimpan foto...";
    notifyListeners();

    try {
      final Position? pos = await gpsFuture;

      if (pos != null && pos.isMocked) {
        _loading = false;
        notifyListeners();
        onFakeGps();
        return;
      }

      final String koordinatGps = (pos != null)
          ? "${pos.latitude.toStringAsFixed(6)},${pos.longitude.toStringAsFixed(6)}"
          : "-6.200000,106.816666";

      final File localFile = await simpanFotoLokal(foto);

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

      _kantongRahasia.add(itemBaru);
      ctrl.clear();

      await _penyimpanan.simpanDraft(_kantongRahasia);
      onSnackbar("✅ $trayName berhasil diverifikasi.", isError: false);
    } catch (e) {
      onSnackbar("Gagal: $e", isError: true);
    } finally {
      if (isMounted()) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> batalkanDariKantong(int index) async {
    final item = _kantongRahasia[index];
    try {
      final localPath = item['fotoLocalPath'];
      if (localPath != null) {
        final f = File(localPath);
        if (await f.exists()) await f.delete();
      }
    } catch (_) {}

    _kantongRahasia.removeAt(index);
    await _penyimpanan.simpanDraft(_kantongRahasia);
    onSnackbar("${item['nama']} dikembalikan ke antrean.", isError: false);
    notifyListeners();
  }

  // ---------- bungkus ----------
  Future<void> prosesBungkusInstan() async {
    if (_isProcessingBungkus || _loading || _kantongRahasia.isEmpty) return;

    _isProcessingBungkus = true;
    _loading = true;
    _statusPesanLoading = "Membungkus data panen...";
    notifyListeners();

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

      await onBungkusBatch(paketBatch);

      final List<String> queue = await _penyimpanan.muatAntreanSync();
      queue.add(jsonEncode(paketBatch, toEncodable: PenyimpananPanen.customJsonSerializer));
      await _penyimpanan.simpanAntreanSync(queue);

      _kantongRahasia.clear();
      await _penyimpanan.hapusDraft();

      onBungkusSelesai();
      onSnackbar("🎉 $batchKode Berhasil Dibungkus! Tersimpan di Menu 4.", isError: false);

      _sinkronisasi?.jalankanProsesSync();
    } catch (e) {
      onSnackbar("Terjadi kesalahan saat membungkus: $e", isError: true);
    } finally {
      if (isMounted()) {
        _loading = false;
        _isProcessingBungkus = false;
        notifyListeners();
      }
    }
  }

  // ---------- sinkronisasi ----------
  void jalankanSync() {
    _sinkronisasi?.jalankanProsesSync();
  }

  // ---------- cleanup ----------
  void disposeController() {
    for (var c in _ctrls.values) {
      c.dispose();
    }
    _ctrls.clear();
    _sinkronisasi = null;
    dispose();
  }
}
