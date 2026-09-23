import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:path_provider/path_provider.dart';

class MenuTiga extends StatefulWidget {
  final List<Map<String, dynamic>> daftarPanen;
  final Future<void> Function(Map<String, dynamic>) onBungkusBatch;
  final Future<void> Function(String batchKode, List<dynamic> detailTrays) onUpdateFotoBatch;

  // ⚙️ KONFIGURASI CLOUDINARY
  static const String cloudName = 'CLOUDINARY_CLOUD_NAME'; 
  static const String uploadPreset = 'CLOUDINARY_UPLOAD_PRESET';   

  const MenuTiga({
    super.key,
    required this.daftarPanen,
    required this.onBungkusBatch,
    required this.onUpdateFotoBatch,
  });

  @override
  State<MenuTiga> createState() => _MenuTigaState();
}

class _MenuTigaState extends State<MenuTiga>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  final Map<String, TextEditingController> _ctrls = {};
  List<Map<String, dynamic>> _kantongRahasia = [];
  Set<String> _trayTelahDibungkus = {}; // 🔒 Menyimpan tray yang sudah dibungkus agar tidak balik lagi
  bool _loading = false;
  bool _isInitLoading = true;
  bool _isProcessingBungkus = false; // 🔒 Mencegah spam klik tombol bungkus
  String _statusPesanLoading = "Memproses...";

  late TabController _tabController;
  static const String _storageDraftKey = 'DRAFT_PANEN_TEMPORER_MAGGOT';
  static const String _storageQueueKey = 'ANTREAN_SYNC_LATAR_BELAKANG_MAGGOT';
  static const String _storageTrayDibungkusKey = 'LIST_TRAY_SELESAI_DIBUNGKUS_MAGGOT';

  final ImagePicker _picker = ImagePicker();
  static bool _sedangSyncLatarBelakang = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _muatDataLokal();

    // Otomatis cek dan sinkronisasi antrean yang tertunda di latar belakang
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _jalankanSyncLatarBelakang();
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
  // 1. MANAJEMEN PENYIMPANAN LOCAL & ANTREAN SENYAP
  // ==========================================================
  Future<void> _muatDataLokal() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Muat Tray yang sudah selesai dibungkus
      final List<String>? listDibungkus = prefs.getStringList(_storageTrayDibungkusKey);
      if (listDibungkus != null) {
        _trayTelahDibungkus = listDibungkus.toSet();
      }

      // Muat Draft Siap Kirim
      final String? draftJson = prefs.getString(_storageDraftKey);
      if (draftJson != null && draftJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(draftJson);
        _kantongRahasia = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      debugPrint("Gagal membaca storage lokal: $e");
    } finally {
      if (mounted) setState(() => _isInitLoading = false);
    }
  }

  Future<void> _simpanDraftKeDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String jsonStr = jsonEncode(_kantongRahasia, toEncodable: _customJsonSerializer);
      await prefs.setString(_storageDraftKey, jsonStr);
    } catch (_) {}
  }

  Future<void> _hapusDraftDariDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageDraftKey);
    } catch (_) {}
  }

  dynamic _customJsonSerializer(dynamic item) {
    if (item is Timestamp) {
      return item.toDate().toIso8601String();
    } else if (item is DateTime) {
      return item.toIso8601String();
    }
    return item.toString();
  }

  // Saring antrean: Bukan yang ada di Siap Kirim DAN Bukan yang sudah Pernah Dibungkus
  List<Map<String, dynamic>> get _antreanAktif {
    final Set<String> namaDiKantong =
        _kantongRahasia.map((e) => e['nama'].toString()).toSet();

    return widget.daftarPanen.where((item) {
      final String nama = item['nama'].toString();
      final bool sudahDiKantong = namaDiKantong.contains(nama);
      final bool sudahDibungkus = _trayTelahDibungkus.contains(nama);
      return !sudahDiKantong && !sudahDibungkus;
    }).toList();
  }

  TextEditingController _getController(String key) {
    if (!_ctrls.containsKey(key)) {
      _ctrls[key] = TextEditingController();
    }
    return _ctrls[key]!;
  }

  // ==========================================================
  // 2. KONEKSI & GPS
  // ==========================================================
  Future<bool> _cekAdaInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.location_off, color: Colors.red, size: 26),
            SizedBox(width: 8),
            Text("GPS Belum Aktif!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text(
          "GPS wajib aktif agar titik koordinat panen terekam. (GPS satelit tetap bekerja meski tanpa kuota/sinyal).",
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("BATAL", style: TextStyle(color: Colors.grey))),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await Geolocator.openLocationSettings();
            },
            icon: const Icon(Icons.settings, size: 16),
            label: const Text("AKTIFKAN GPS"),
          ),
        ],
      ),
    );
  }

  void _tampilkanDialogIzinPermanen() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Izin Lokasi Diblokir", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text("Silakan izinkan akses lokasi melalui Pengaturan Aplikasi.", style: TextStyle(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("BATAL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800], foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await Geolocator.openAppSettings();
            },
            child: const Text("PENGATURAN"),
          ),
        ],
      ),
    );
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

  // ==========================================================
  // 3. VERIFIKASI TRAY
  // ==========================================================
  Future<void> _verifikasi(Map<String, dynamic> data) async {
    final String trayName = data['nama']?.toString() ?? 'Tray';
    final bool isGagal = data['status'] == "GAGAL";
    final ctrl = _getController(trayName);

    if (!isGagal && ctrl.text.trim().isEmpty) {
      _showSnackbar("Isi berat hasil panen $trayName terlebih dahulu!", isError: true);
      return;
    }

    final bool gpsSiap = await _pastikanGpsAktif();
    if (!gpsSiap) return;

    final gpsFuture = _getFastLocation();
    final cameraFuture = _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1280,
      maxHeight: 1280,
    );

    final XFile? foto = await cameraFuture;
    if (foto == null) return;

    setState(() {
      _loading = true;
      _statusPesanLoading = "Menyimpan foto ke memori HP...";
    });

    try {
      final Position? pos = await gpsFuture;
      final String koordinatGps = (pos != null)
          ? "${pos.latitude.toStringAsFixed(6)},${pos.longitude.toStringAsFixed(6)}"
          : "-6.200000,106.816666";

      // Simpan file lokal di HP
      final Directory docDir = await getApplicationDocumentsDirectory();
      final String fileName = "panen_${DateTime.now().millisecondsSinceEpoch}.jpg";
      final File localFile = await File(foto.path).copy('${docDir.path}/$fileName');

      String tglMulaiFormatted = "-";
      if (data['tanggalMulai'] != null) {
        var tgl = data['tanggalMulai'];
        DateTime dt = (tgl is Timestamp)
            ? tgl.toDate()
            : (tgl is DateTime ? tgl : DateTime.now());
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

      await _simpanDraftKeDisk();
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
    await _simpanDraftKeDisk();
    _showSnackbar("${item['nama']} dikembalikan ke antrean.");
  }

  // ==========================================================
  // 4. BUNGKUS BATCH INSTAN + CEGAH DUPLIKASI SPAM
  // ==========================================================
  Future<void> _prosesBungkusInstan() async {
    // 🔒 PENGAMAN: Jika sedang memproses atau data kosong, tolak klik tambahan!
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

      // 1. Catat nama-nama tray agar permanen HILANG dari antrean Menu 3
      for (var item in _kantongRahasia) {
        _trayTelahDibungkus.add(item['nama'].toString());
      }
      await prefs.setStringList(_storageTrayDibungkusKey, _trayTelahDibungkus.toList());

      // 2. Kirim Ringkasan ke Menu 4 (Offline/Online otomatis via callback)
      await widget.onBungkusBatch(paketBatch);

      // 3. Masukkan ke Antrean Sync Latar Belakang (Menunggu Sinyal)
      final List<String> queue = prefs.getStringList(_storageQueueKey) ?? [];
      queue.add(jsonEncode(paketBatch, toEncodable: _customJsonSerializer));
      await prefs.setStringList(_storageQueueKey, queue);

      // 4. Bersihkan Tab Siap Kirim & Hapus Draft Sementara
      _kantongRahasia.clear();
      await _hapusDraftDariDisk();

      _tabController.animateTo(0);
      _showSnackbar("🎉 $batchKode Berhasil Dibungkus! Tersimpan di Menu 4.", isError: false);

      // 5. Coba jalankan sinkronisasi senyap jika langsung ada internet
      _jalankanSyncLatarBelakang();
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

  // Mesin Latar Belakang: Upload foto & kirim batch saat internet stabil
  Future<void> _jalankanSyncLatarBelakang() async {
    if (_sedangSyncLatarBelakang) return;
    _sedangSyncLatarBelakang = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> queue = prefs.getStringList(_storageQueueKey) ?? [];
      if (queue.isEmpty) {
        _sedangSyncLatarBelakang = false;
        return;
      }

      final bool online = await _cekAdaInternet();
      if (!online) {
        _sedangSyncLatarBelakang = false;
        return; // Tunggu koneksi internet tersedia
      }

      final cloudinary = CloudinaryPublic(MenuTiga.cloudName, MenuTiga.uploadPreset, cache: false);
      final List<String> sisaQueue = [];

      for (String batchRaw in queue) {
        try {
          Map<String, dynamic> batch = jsonDecode(batchRaw);
          List<dynamic> details = batch['detailTrays'] ?? [];

          // Upload semua foto biopon ke Cloudinary
          for (var tray in details) {
            String existingUrl = tray['fotoUrl'] ?? '';
            String? localPath = tray['fotoLocalPath'];

            if (existingUrl.isEmpty && localPath != null && localPath.isNotEmpty) {
              File f = File(localPath);
              if (await f.exists()) {
                CloudinaryResponse res = await cloudinary.uploadFile(
                  CloudinaryFile.fromFile(localPath, resourceType: CloudinaryResourceType.Image, folder: 'panen_maggot'),
                );
                tray['fotoUrl'] = res.secureUrl;
                try {
                  await f.delete(); // Hapus file lokal setelah aman di cloud
                } catch (_) {}
              }
            }
          }

          // Konversi format tanggal kembali ke Timestamp
          if (batch['tanggalBungkus'] is String) {
            batch['tanggalBungkus'] = Timestamp.fromDate(DateTime.parse(batch['tanggalBungkus']));
          }

          // Perbarui data dengan URL foto ke Admin Firestore
          final String batchKodeSync = batch['batchKode'] ?? '';
if (batchKodeSync.isNotEmpty) {
  await widget.onUpdateFotoBatch(batchKodeSync, details);
}
        } catch (e) {
          debugPrint("Sync tertunda: $e");
          sisaQueue.add(batchRaw);
        }
      }

      await prefs.setStringList(_storageQueueKey, sisaQueue);
    } catch (_) {
    } finally {
      _sedangSyncLatarBelakang = false;
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
  // 5. USER INTERFACE
  // ==========================================================
  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isInitLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text("Memuat data panen..."),
            ],
          ),
        ),
      );
    }

    final antrean = _antreanAktif;
    final kantong = _kantongRahasia;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          "Verifikasi Panen Maggot",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue[900],
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: Colors.blue[900],
          indicatorWeight: 3,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.format_list_bulleted, size: 18),
                  const SizedBox(width: 8),
                  Text("Antrean (${antrean.length})", style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.archive_outlined, size: 18),
                  const SizedBox(width: 8),
                  Text("Siap Kirim (${kantong.length})", style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildTabAntrean(antrean),
              _buildTabKantong(kantong),
            ],
          ),
          if (_loading)
            Container(
              color: Colors.black45,
              child: Center(
                child: Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          _statusPesanLoading,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: kantong.isNotEmpty ? _buildBottomButton(kantong.length) : null,
    );
  }

  Widget _buildBottomButton(int totalItem) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -3))],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _isProcessingBungkus ? Colors.grey : Colors.orange[800],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 2,
            ),
            // Tombol disable seketika saat proses berjalan untuk mencegah spam klik
            onPressed: (_loading || _isProcessingBungkus) ? null : _prosesBungkusInstan,
            icon: const Icon(Icons.inventory_2_rounded),
            label: Text(
              _isProcessingBungkus ? "MEMBUNGKUS..." : "BUNGKUS $totalItem TRAY SELESAI",
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabAntrean(List<Map<String, dynamic>> antrean) {
    if (antrean.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 70, color: Colors.green[400]),
            const SizedBox(height: 12),
            const Text("Semua Tray Telah Diverifikasi", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              _kantongRahasia.isNotEmpty
                  ? "Buka tab 'Siap Kirim' untuk membungkus."
                  : "Semua tray hari ini telah selesai diproses.",
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: antrean.length,
      itemBuilder: (context, index) {
        final d = antrean[index];
        final String nama = d['nama']?.toString() ?? 'Tray';
        final bool isGagal = d['status'] == "GAGAL";
        final controller = _getController(nama);

        return Card(
          elevation: 1.5,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: isGagal ? Colors.red[100] : Colors.green[100],
                      child: Icon(
                        isGagal ? Icons.close : Icons.eco,
                        color: isGagal ? Colors.red[800] : Colors.green[800],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(nama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(
                            isGagal ? "Kondisi: Panen Gagal" : "Siap Panen",
                            style: TextStyle(
                              fontSize: 12,
                              color: isGagal ? Colors.red[700] : Colors.green[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (!isGagal)
                  TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: "Berat Hasil Panen (Kg)",
                      suffixText: "Kg",
                      prefixIcon: const Icon(Icons.scale_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.red, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Wajib ambil foto bukti maggot mati.",
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isGagal ? Colors.red[700] : Colors.blue[800],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: (_loading || _isProcessingBungkus) ? null : () => _verifikasi(d),
                    icon: const Icon(Icons.camera_alt, size: 18),
                    label: Text(
                      isGagal ? "FOTO BUKTI MATI" : "AMBIL FOTO & VERIFIKASI",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabKantong(List<Map<String, dynamic>> kantong) {
    if (kantong.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 10),
            const Text(
              "Belum Ada Tray Siap Kirim",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            const Text("Verifikasi tray terlebih dahulu dari Tab Antrean.", style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: kantong.length,
      itemBuilder: (context, index) {
        final item = kantong[index];
        final bool isGagal = item['status'] == "GAGAL";
        final String? localPath = item['fotoLocalPath'];

        Widget fotoThumbnail;
        if (localPath != null && File(localPath).existsSync()) {
          fotoThumbnail = Image.file(
            File(localPath),
            width: 55,
            height: 55,
            fit: BoxFit.cover,
          );
        } else {
          fotoThumbnail = Container(
            width: 55,
            height: 55,
            color: Colors.grey[300],
            child: const Icon(Icons.camera_alt, color: Colors.grey),
          );
        }

        return Card(
          elevation: 1.5,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: fotoThumbnail,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['nama'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        isGagal ? "Status: GAGAL" : "Hasil: ${item['hasilKg']} Kg",
                        style: TextStyle(
                          color: isGagal ? Colors.red : Colors.green[800],
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Text("📍 GPS: ${item['gps']}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: "Kembalikan ke antrean",
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: (_loading || _isProcessingBungkus) ? null : () => _batalkanDariKantong(index),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}