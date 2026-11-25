import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'backend/firebase_options.dart';
import 'backend/auth_service.dart';
import 'backend/maggot_repository.dart';

// Import File Menu & Halaman
import 'frontend/login_page.dart';
import 'frontend/email_verification_page.dart';
import 'frontend/profil_tidak_ditemukan_page.dart';
import 'frontend/dashboard_admin_web.dart';
import 'frontend/menu1.dart';
import 'frontend/menu2.dart';
import 'frontend/menu3.dart';
import 'frontend/menu4.dart';
import 'frontend/page_artikel.dart';
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
            onTambahBanyakData: (daftarTray) => MaggotRepository.tambahBanyakTray(
              uid: user.uid,
              namaMitra: userData['nama'] ?? "Mitra",
              counterAwal: userData['counterTray'] ?? 1,
              daftarTrayBaru: daftarTray,
              dbSiklusLama: dbSiklus,
            ),
          ),
          MenuDua(
            daftarSiklus: dbSiklus,
            onKonfirmasiSehat: (index, minggu) => MaggotRepository.konfirmasiSehat(
              uid: user.uid,
              dbSiklus: dbSiklus,
              index: index,
              minggu: minggu,
            ),
            onPanenOtomatis: (index, dataPanen) => MaggotRepository.pindahkanKePanen(
              uid: user.uid,
              dbSiklus: dbSiklus,
              dbPanen: dbPanen,
              index: index,
              dataBaru: dataPanen,
            ),
            onGagalKePanen: (index, dataGagal) => MaggotRepository.pindahkanKePanen(
              uid: user.uid,
              dbSiklus: dbSiklus,
              dbPanen: dbPanen,
              index: index,
              dataBaru: dataGagal,
            ),
          ),
          MenuTiga(
            daftarPanen: dbPanen,
            onBungkusBatch: (paketBatch) => MaggotRepository.bungkusBatch(
              uid: user.uid,
              paketBatch: paketBatch,
              dbPanenLama: dbPanen,
            ),
            onUpdateFotoBatch: (batchKode, detailTrays) => MaggotRepository.updateFotoBatch(
              uid: user.uid,
              batchKode: batchKode,
              detailTraysTerbaru: detailTrays,
            ),
          ),
          MenuEmpat(
            daftarBatch: dbBatch,
            onHapusBatchManual: (index) => MaggotRepository.hapusBatchManual(
              uid: user.uid,
              dbBatch: dbBatch,
              index: index,
            ),
          ),
          const PageArtikel(),
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
              BottomNavigationBarItem(icon: Icon(Icons.article_outlined), label: 'Artikel'),
            ],
          ),
        );
      },
    );
  }
}

// =========================================================================
// 4. HELPER WIDGET
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
