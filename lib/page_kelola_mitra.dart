import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Cloud Functions dihapus karena butuh paket Blaze (berbayar)
import 'auth_service.dart';

// =============================================================================
// MODEL ENTITY TYPE-SAFE (CLEAN ARCHITECTURE)
// =============================================================================
class MitraItem {
  final String uid;
  final String nama;
  final String email;
  final int counterTray;
  final List<dynamic> siklus;

  MitraItem({
    required this.uid,
    required this.nama,
    required this.email,
    required this.counterTray,
    required this.siklus,
  });

  factory MitraItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final rawSiklus = data['siklus'];
    return MitraItem(
      uid: doc.id,
      nama: (data['nama'] ?? "Tanpa Nama").toString().trim(),
      email: (data['email'] ?? "-").toString().trim(),
      counterTray: data['counterTray'] is int
          ? data['counterTray'] as int
          : int.tryParse(data['counterTray']?.toString() ?? "1") ?? 1,
      siklus: rawSiklus is List ? rawSiklus : [],
    );
  }

  String get inisial {
    if (nama.isEmpty || nama == "Tanpa Nama") return "?";
    return nama[0].toUpperCase();
  }
}

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

  bool _loadingTambah = false;
  String _cari = "";
  Timer? _debounceTimer;

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
  // FUNGSI PENCARIAN DENGAN DEBOUNCE (ANTI-JANK)
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
  // FUNGSI TAMBAH / SINKRONISASI MITRA
  // =========================================================================
  Future<void> _tambahMitra(BuildContext context, StateSetter setDialogState) async {
    final String nama = _namaCtrl.text.trim();
    final String email = _emailCtrl.text.trim();
    final String pass = _passCtrl.text.trim();

    if (nama.isEmpty || email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Lengkapi semua data!"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setDialogState(() => _loadingTambah = true);

    // Pakai fungsi yang SUDAH cek role admin di Firestore sebelum bikin akun
    final String? error = await AuthService().adminBuatAkunMitra(email, pass, nama);

    if (mounted) {
      setDialogState(() => _loadingTambah = false);
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Mitra Baru Berhasil Ditambahkan"),
          backgroundColor: Colors.green,
        ),
      );
      _namaCtrl.clear();
      _emailCtrl.clear();
      _passCtrl.clear();
    }
  }

  // =========================================================================
  // FUNGSI RESET COUNTER DENGAN SAFETY GUARD
  // =========================================================================
  void _konfirmasiResetCounter(String uid, String nama) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.refresh_rounded, color: Colors.blueGrey),
            SizedBox(width: 8),
            Text("Reset Counter?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          "Apakah Anda yakin ingin me-reset urutan counter tray untuk mitra '$nama' kembali ke 1?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("BATAL", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey[800],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _eksekusiResetCounter(uid, nama);
            },
            child: const Text("YA, RESET"),
          ),
        ],
      ),
    );
  }

  Future<void> _eksekusiResetCounter(String uid, String nama) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'counterTray': 1,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

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
  // FUNGSI HAPUS MITRA (HANYA DARI FIRESTORE - TANPA CLOUD FUNCTIONS)
  // =========================================================================
  void _konfirmasiHapus(String uid, String nama) {
    bool loadingHapus = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text("Hapus Mitra?", style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text(
            "Apakah Anda yakin ingin menghapus data mitra '$nama' dari database?",
          ),
          actions: [
            TextButton(
              onPressed: loadingHapus ? null : () => Navigator.pop(dialogCtx),
              child: const Text("BATAL", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: loadingHapus
                  ? null
                  : () async {
                      setDialogState(() => loadingHapus = true);
                      try {
                        // HAPUS HANYA DARI CLOUD FIRESTORE (Gratis & gak butuh Blaze)
                        await FirebaseFirestore.instance
                            .collection('akun_auth_perlu_dihapus')
                            .doc(uid)
                            .set({
                          'nama': nama,
                          'uid': uid,
                          'dihapusPada': FieldValue.serverTimestamp(),
                        });

                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(uid)
                            .delete();

                        if (mounted) {
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Data mitra $nama berhasil dihapus."),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => loadingHapus = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Gagal menghapus: $e"),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: loadingHapus
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text("HAPUS"),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // DIALOG FORM TAMBAH MITRA
  // =========================================================================
  void _showTambahDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text("Tambah Mitra Baru", style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _namaCtrl,
                  decoration: const InputDecoration(
                    labelText: "Nama Lengkap",
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Password Default",
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[800],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _loadingTambah ? null : () => _tambahMitra(context, setDialogState),
              child: _loadingTambah
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text("SIMPAN"),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text("Terjadi kesalahan: ${snapshot.error}"));
        }

        // Filter dokumen role 'mitra' dan parsing ke Entity MitraItem
        final semuaMitra = (snapshot.data?.docs ?? [])
            .where((d) {
              final data = d.data() as Map<String, dynamic>? ?? {};
              return data['role'] == 'mitra';
            })
            .map((doc) => MitraItem.fromFirestore(doc))
            .toList();

        final int totalMitra = semuaMitra.length;

        int totalTrayAktif = 0;
        for (var mitra in semuaMitra) {
          totalTrayAktif += mitra.siklus.length;
        }

        // Filter lokal berdasarkan input pencarian
        final listMitraTampil = semuaMitra.where((mitra) {
          return mitra.nama.toLowerCase().contains(_cari);
        }).toList();

        return LayoutBuilder(
          builder: (context, constraints) {
            final isSmallScreen = constraints.maxWidth < 600;

            return Column(
              children: [
                // HEADER STATISTIK SINGKAT & INPUT PENCARIAN
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          _buildStatChip(
                            icon: Icons.people_alt_rounded,
                            color: const Color(0xFF1E88E5),
                            title: "Total Mitra",
                            value: "$totalMitra Orang",
                          ),
                          _buildStatChip(
                            icon: Icons.layers_rounded,
                            color: const Color(0xFF2E7D32),
                            title: "Tray Aktif",
                            value: "$totalTrayAktif Tray",
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (isSmallScreen) ...[
                        TextField(
                          controller: _searchCtrl,
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            hintText: "Cari nama mitra...",
                            prefixIcon: const Icon(Icons.search, size: 20),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: _showTambahDialog,
                          icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                          label: const Text("TAMBAH MITRA", style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[800],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 1,
                          ),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchCtrl,
                                onChanged: _onSearchChanged,
                                decoration: InputDecoration(
                                  hintText: "Cari nama mitra...",
                                  prefixIcon: const Icon(Icons.search, size: 20),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _showTambahDialog,
                              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                              label: const Text("TAMBAH MITRA", style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[800],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 1,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const Divider(height: 1, thickness: 1),

                // GRID DAFTAR MITRA
                Expanded(
                  child: listMitraTampil.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_off_outlined, size: 50, color: Colors.grey[400]),
                              const SizedBox(height: 8),
                              Text(
                                _cari.isEmpty
                                    ? "Belum ada mitra terdaftar"
                                    : "Mitra '$_cari' tidak ditemukan",
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(20),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 360,
                            mainAxisExtent: 145,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: listMitraTampil.length,
                          itemBuilder: (ctx, i) {
                            final mitra = listMitraTampil[i];

                            return Card(
                              elevation: 1.5,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: Colors.grey.shade200),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: const Color(0xFF455A64),
                                          foregroundColor: Colors.white,
                                          child: Text(
                                            mitra.inisial,
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            mitra.nama,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        _buildActionMenu(mitra.uid, mitra.nama),
                                      ],
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.layers_outlined,
                                                size: 15,
                                                color: Colors.blueGrey,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                "Tray Aktif: ${mitra.siklus.length}",
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            "ID: #${mitra.counterTray}",
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  // MENU POPUP (RESET COUNTER DENGAN KONFIRMASI & HAPUS)
  Widget _buildActionMenu(String uid, String nama) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      itemBuilder: (ctx) => [
        const PopupMenuItem(
          value: 'reset',
          child: Row(
            children: [
              Icon(Icons.refresh, size: 18, color: Colors.blueGrey),
              SizedBox(width: 8),
              Text("Reset Counter"),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'hapus',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18, color: Colors.red),
              SizedBox(width: 8),
              Text("Hapus Mitra", style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
      onSelected: (val) {
        if (val == 'reset') {
          _konfirmasiResetCounter(uid, nama);
        } else if (val == 'hapus') {
          _konfirmasiHapus(uid, nama);
        }
      },
    );
  }
}