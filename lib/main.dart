import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';

// Import File Menu & Halaman
import 'auth_service.dart';
import 'login_page.dart';
import 'email_verification_page.dart';
import 'profil_tidak_ditemukan_page.dart';
import 'dashboard_admin_web.dart';
import 'menu1.dart';
import 'menu2.dart';
import 'menu3.dart';
import 'menu4.dart';

// =========================================================================
// 1. ENTRY POINT & INITIALIZATION
// =========================================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Tangkap error Flutter Framework
  FlutterError.onError = (errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };

  // Tangkap error di luar framework (Isolate)
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  runApp(const AplikasiMaggot());
}

// =========================================================================
// 2. ROOT APP & AUTH GATEWAY
// =========================================================================
class AplikasiMaggot extends StatelessWidget {
  const AplikasiMaggot({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: StreamBuilder<User?>(
        stream: AuthService().userStream,
        builder: (context, authSnapshot) {
          if (authSnapshot.connectionState == ConnectionState.waiting) {
            return const _LoadingScreen();
          }

          final User? user = authSnapshot.data;
          if (user == null) return const LoginPage();

          return _UserRoleRouter(user: user);
        },
      ),
    );
  }
}

// Menangani Pengalihan Role (Admin, Mitra Belum Verif, Mitra Aktif)
class _UserRoleRouter extends StatelessWidget {
  final User user;
  const _UserRoleRouter({required this.user});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, userSnap) {
        if (!userSnap.hasData) return const _LoadingScreen();

        final userData = userSnap.data!.data() as Map<String, dynamic>?;
        if (userData == null) return const ProfilTidakDitemukanPage();

        if (userData['role'] == 'admin') {
          return const DashboardAdminWeb();
        }

        if (!user.emailVerified) {
          return const EmailVerificationPage();
        }

        return const HalamanNavigasi();
      },
    );
  }
}

// =========================================================================
// 3. HALAMAN NAVIGASI UTAMA
// =========================================================================
class HalamanNavigasi extends StatefulWidget {
  const HalamanNavigasi({super.key});

  @override
  State<HalamanNavigasi> createState() => _HalamanNavigasiState();
}

class _HalamanNavigasiState extends State<HalamanNavigasi> {
  int _indexMenu = 0;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const LoginPage();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const _LoadingScreen();

        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        if (userData == null) return const ProfilTidakDitemukanPage();

        final List<Map<String, dynamic>> dbSiklus = List<Map<String, dynamic>>.from(userData['siklus'] ?? []);
        final List<Map<String, dynamic>> dbPanen = List<Map<String, dynamic>>.from(userData['panen'] ?? []);
        final List<Map<String, dynamic>> dbBatch = List<Map<String, dynamic>>.from(userData['batch'] ?? []);

        // Definisi Halaman Bersih (Logika Firestore dipindah ke Repository)
        final List<Widget> halaman = [
          MenuSatu(
            nomorTrayOtomatis: userData['counterTray'] ?? 1,
            namaMitra: userData['nama'] ?? "Mitra",
            onTambahBanyakData: (daftarTray) => _MaggotRepository.tambahBanyakTray(
              uid: user.uid,
              namaMitra: userData['nama'] ?? "Mitra",
              counterAwal: userData['counterTray'] ?? 1,
              daftarTrayBaru: daftarTray,
              dbSiklusLama: dbSiklus,
            ),
          ),
          MenuDua(
            daftarSiklus: dbSiklus,
            onKonfirmasiSehat: (index, minggu) => _MaggotRepository.konfirmasiSehat(
              uid: user.uid,
              dbSiklus: dbSiklus,
              index: index,
              minggu: minggu,
            ),
            onPanenOtomatis: (index, dataPanen) => _MaggotRepository.pindahkanKePanen(
              uid: user.uid,
              dbSiklus: dbSiklus,
              dbPanen: dbPanen,
              index: index,
              dataBaru: dataPanen,
            ),
            onGagalKePanen: (index, dataGagal) => _MaggotRepository.pindahkanKePanen(
              uid: user.uid,
              dbSiklus: dbSiklus,
              dbPanen: dbPanen,
              index: index,
              dataBaru: dataGagal,
            ),
          ),
          MenuTiga(
            daftarPanen: dbPanen,
            onBungkusBatch: (paketBatch) => _MaggotRepository.bungkusBatch(
              uid: user.uid,
              paketBatch: paketBatch,
              dbPanenLama: dbPanen,
            ),
            onUpdateFotoBatch: (batchKode, detailTrays) => _MaggotRepository.updateFotoBatch(
              uid: user.uid,
              batchKode: batchKode,
              detailTraysTerbaru: detailTrays,
            ),
          ),
          MenuEmpat(
            daftarBatch: dbBatch,
            onHapusBatchManual: (index) => _MaggotRepository.hapusBatchManual(
              uid: user.uid,
              dbBatch: dbBatch,
              index: index,
            ),
          ),
        ];

        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("MAGG", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text("Mitra: ${userData['nama']}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
              ],
            ),
            backgroundColor: Colors.green[700],
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                onPressed: () => AuthService().logout(),
                icon: const Icon(Icons.logout_rounded),
                tooltip: "Keluar Aplikasi",
              )
            ],
          ),
          body: halaman[_indexMenu],
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _indexMenu,
            selectedItemColor: Colors.green[800],
            unselectedItemColor: Colors.grey,
            showUnselectedLabels: true,
            type: BottomNavigationBarType.fixed,
            onTap: (i) => setState(() => _indexMenu = i),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: 'Input'),
              BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined), label: 'Pantau'),
              BottomNavigationBarItem(icon: Icon(Icons.camera_alt_outlined), label: 'Lapor'),
              BottomNavigationBarItem(icon: Icon(Icons.history_toggle_off), label: 'Riwayat'),
            ],
          ),
        );
      },
    );
  }
}

// =========================================================================
// 4. REPOSITORY LAYER (Pusat Transaksi & Operasi Firestore)
// =========================================================================
class _MaggotRepository {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Menu 1: Tambah Banyak Tray Sekaligus
  static Future<void> tambahBanyakTray({
    required String uid,
    required String namaMitra,
    required int counterAwal,
    required List<Map<String, dynamic>> daftarTrayBaru,
    required List<Map<String, dynamic>> dbSiklusLama,
  }) async {
    final List<Map<String, dynamic>> hasilBaru = [];

    for (int i = 0; i < daftarTrayBaru.length; i++) {
      final item = daftarTrayBaru[i];
      hasilBaru.add({
        "peternak": namaMitra,
        "nama": "Tray ${counterAwal + i}",
        "beratTelur": item['beratTelur'],
        "tanggalMulai": item['tanggalMulai'],
        "cekM1": null,
        "cekM2": null,
      });
    }

    dbSiklusLama.addAll(hasilBaru);

    await _db.collection('users').doc(uid).update({
      'siklus': dbSiklusLama,
      'counterTray': counterAwal + daftarTrayBaru.length,
    });
  }

  // Menu 2: Verifikasi Sehat M1/M2
  static Future<void> konfirmasiSehat({
    required String uid,
    required List<Map<String, dynamic>> dbSiklus,
    required int index,
    required int minggu,
  }) async {
    dbSiklus[index]['cekM$minggu'] = DateTime.now().toIso8601String();
    await _db.collection('users').doc(uid).update({'siklus': dbSiklus});
  }

  // Menu 2: Pindah dari Siklus ke Panen
  static Future<void> pindahkanKePanen({
    required String uid,
    required List<Map<String, dynamic>> dbSiklus,
    required List<Map<String, dynamic>> dbPanen,
    required int index,
    required Map<String, dynamic> dataBaru,
  }) async {
    dbPanen.add(dataBaru);
    dbSiklus.removeAt(index);
    await _db.collection('users').doc(uid).update({
      'siklus': dbSiklus,
      'panen': dbPanen,
    });
  }

  // Menu 3: Bungkus Batch Atomik (Sub-koleksi + Ringkasan Ringan)
  static Future<void> bungkusBatch({
    required String uid,
    required Map<String, dynamic> paketBatch,
    required List<Map<String, dynamic>> dbPanenLama,
  }) async {
    final List<dynamic> detailTrays = paketBatch['detailTrays'] ?? [];
    final Set<String> namaTraySelesai = detailTrays.map((t) => t['nama'].toString()).toSet();

    final sisaPanen = dbPanenLama.where((item) => !namaTraySelesai.contains(item['nama'].toString())).toList();
    final String batchKode = paketBatch['batchKode'] ?? "BATCH-${DateTime.now().millisecondsSinceEpoch}";

    final batchWrite = _db.batch();

    // 1. Simpan detail penuh ke Sub-koleksi
    final docBatchRef = _db.collection('users').doc(uid).collection('batches').doc(batchKode);
    batchWrite.set(docBatchRef, paketBatch);

    // 2. Buat ringkasan ringan untuk Menu 4 (Anti limit 1MB Firestore)
    final ringkasanMenuEmpat = {
      'batchKode': batchKode,
      'tanggalBungkus': paketBatch['tanggalBungkus'],
      'tanggalFormatted': paketBatch['tanggalFormatted'],
      'totalBeratKg': paketBatch['totalBeratKg'],
      'jumlahTray': paketBatch['jumlahTray'],
      'status': paketBatch['status'],
      'daftarNamaTray': detailTrays.map((e) => e['nama']).toList(),
    };

    // 3. Simpan ke Dokumen Utama
    final docUserRef = _db.collection('users').doc(uid);
    batchWrite.update(docUserRef, {
      'panen': sisaPanen,
      'batch': FieldValue.arrayUnion([ringkasanMenuEmpat]),
    });

    await batchWrite.commit();
  }

  // Menu 3: Update URL Foto Cloudinary ke Sub-koleksi Batches
  static Future<void> updateFotoBatch({
    required String uid,
    required String batchKode,
    required List<dynamic> detailTraysTerbaru,
  }) async {
    await _db.collection('users').doc(uid).collection('batches').doc(batchKode).update({
      'detailTrays': detailTraysTerbaru,
    });
  }

  // Menu 4: Hapus Batch Manual
  static Future<void> hapusBatchManual({
    required String uid,
    required List<Map<String, dynamic>> dbBatch,
    required int index,
  }) async {
    dbBatch.removeAt(index);
    await _db.collection('users').doc(uid).update({'batch': dbBatch});
  }
}

// =========================================================================
// 5. HELPER WIDGET
// =========================================================================
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}