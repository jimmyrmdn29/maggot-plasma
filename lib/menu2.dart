import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_config.dart'; // ⚙️ HARI_AUTO_PANEN & konfigurasi lain

// =========================================================================
// 1. HELPER FASE MAGGOT (Memisahkan Logika Gambar & Umur dari UI)
// =========================================================================
class _FaseMaggotHelper {
  final String label;
  final String pathGambar;

  const _FaseMaggotHelper({required this.label, required this.pathGambar});

  factory _FaseMaggotHelper.dariUmur(int hari) {
    if (hari <= 5) {
      return const _FaseMaggotHelper(
        label: "TELUR",
        pathGambar: "assets/images/telur.png",
      );
    } else if (hari <= 13) {
      return const _FaseMaggotHelper(
        label: "BABY",
        pathGambar: "assets/images/baby_maggot.png",
      );
    } else {
      return const _FaseMaggotHelper(
        label: "MAGGOT LAPAR",
        pathGambar: "assets/images/maggot_lapar.png",
      );
    }
  }
}

// =========================================================================
// 2. WIDGET UTAMA (MENU DUA)
// =========================================================================
class MenuDua extends StatefulWidget {
  final List<Map<String, dynamic>> daftarSiklus;
  final Function(int, int) onKonfirmasiSehat;
  final Function(int, Map<String, dynamic>) onPanenOtomatis;
  final Function(int, Map<String, dynamic>) onGagalKePanen;

  const MenuDua({
    super.key,
    required this.daftarSiklus,
    required this.onKonfirmasiSehat,
    required this.onPanenOtomatis,
    required this.onGagalKePanen,
  });

  @override
  State<MenuDua> createState() => _MenuDuaState();
}

class _MenuDuaState extends State<MenuDua> {
  final Set<String> _processedTray = {};

  @override
  Widget build(BuildContext context) {
    if (widget.daftarSiklus.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F5F5),
        body: Center(child: Text("Belum ada siklus aktif.")),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: widget.daftarSiklus.length,
        itemBuilder: (context, index) {
          final data = widget.daftarSiklus[index];
          final String trayKey = data['nama']?.toString() ?? "tray_$index";

          // Hitung Umur Tray
          final DateTime tgl = (data["tanggalMulai"] is Timestamp)
              ? (data["tanggalMulai"] as Timestamp).toDate()
              : DateTime.now();
          final int hari = DateTime.now().difference(tgl).inDays;

          // Cek Auto-Panen
          if (hari >= HARI_AUTO_PANEN) {
            _triggerAutoPanen(trayKey, index, data);
            return const SizedBox.shrink();
          }

          return _KartuSiklus(
            index: index,
            data: data,
            hari: hari,
            onKonfirmasiSehat: widget.onKonfirmasiSehat,
            onGagalKePanen: widget.onGagalKePanen,
          );
        },
      ),
    );
  }

  void _triggerAutoPanen(String trayKey, int index, Map<String, dynamic> data) {
    if (!_processedTray.contains(trayKey)) {
      _processedTray.add(trayKey);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onPanenOtomatis(index, {...data, "status": "SIAP PANEN"});
        }
      });
    }
  }
}

// =========================================================================
// 3. WIDGET KARTU SIKLUS (Komponen UI Terisolasi & Rapi)
// =========================================================================
class _KartuSiklus extends StatelessWidget {
  final int index;
  final Map<String, dynamic> data;
  final int hari;
  final Function(int, int) onKonfirmasiSehat;
  final Function(int, Map<String, dynamic>) onGagalKePanen;

  const _KartuSiklus({
    required this.index,
    required this.data,
    required this.hari,
    required this.onKonfirmasiSehat,
    required this.onGagalKePanen,
  });

  @override
  Widget build(BuildContext context) {
    final fase = _FaseMaggotHelper.dariUmur(hari);

    final bool isWaktunyaM1 = (hari >= 7 && hari < 14 && data['cekM1'] == null);
    final bool isWaktunyaM2 = (hari >= 14 && hari < 21 && data['cekM2'] == null);
    final bool perluVerifikasi = isWaktunyaM1 || isWaktunyaM2;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: _buildAvatarMulus(fase.pathGambar),
            title: Text(
              data['nama'] ?? 'Tray',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text("Umur: $hari Hari | Fase: ${fase.label}"),
            trailing: _buildBadgeStatus(perluVerifikasi),
          ),
          const Divider(height: 1),
          if (perluVerifikasi)
            _buildPanelVerifikasi(isWaktunyaM1)
          else
            _buildInfoTunggu(),
        ],
      ),
    );
  }

  // Avatar Gambar Bulat Mulus (Anti Semut / Gerigi)
  Widget _buildAvatarMulus(String pathGambar) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        image: DecorationImage(
          image: ResizeImage(
            AssetImage(pathGambar),
            width: 150,
          ),
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }

  Widget _buildBadgeStatus(bool perluVerifikasi) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: perluVerifikasi ? Colors.red[100] : Colors.green[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        perluVerifikasi ? "BUTUH CEK" : "TERPANTAU",
        style: TextStyle(
          color: perluVerifikasi ? Colors.red[800] : Colors.green[800],
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPanelVerifikasi(bool isWaktunyaM1) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.yellow[50],
      child: Column(
        children: [
          Text(
            isWaktunyaM1
                ? "⚠️ Verifikasi Kesehatan Minggu 1 (Hari ke-7)"
                : "⚠️ Verifikasi Kesehatan Minggu 2 (Hari ke-14)",
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () => onKonfirmasiSehat(index, isWaktunyaM1 ? 1 : 2),
                  child: const Text("SEHAT", style: TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  onPressed: () => onGagalKePanen(index, {
                    ...data,
                    "status": "GAGAL",
                    "tanggalSelesai": Timestamp.now(),
                  }),
                  child: const Text("MATI"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTunggu() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        hari < 7
            ? "Menunggu Verifikasi Hari ke-7"
            : (hari < 14
                ? "Verifikasi Berikutnya: Hari ke-14"
                : "Menunggu Panen (Hari ke-$HARI_AUTO_PANEN)"),
        style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
      ),
    );
  }
}