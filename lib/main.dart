import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

// ⚙️ KONFIGURASI SEMUA ADA DI: lib/app_config.dart
//    (ubah reset counter tray, hari auto panen, rasio estimasi, kualitas foto)

// Import File Menu Anda
import 'auth_service.dart';
import 'login_page.dart';
import 'email_verification_page.dart';
import 'profil_tidak_ditemukan_page.dart';
import 'dashboard_admin_web.dart';
import 'menu1.dart';
import 'menu2.dart';
import 'menu3.dart';
import 'menu4.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Tangkap semua error Flutter yang gak ke-handle, kirim ke Crashlytics
  FlutterError.onError = (errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };

  // Tangkap error yang terjadi di luar Flutter framework (misal di isolate lain)
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  runApp(const AplikasiMaggot());
}

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
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          if (snapshot.hasData) {
            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(snapshot.data!.uid)
                  .snapshots(),
              builder: (context, userSnap) {
                if (!userSnap.hasData) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                }

                var userData = userSnap.data!.data() as Map<String, dynamic>?;
                if (userData == null) return const ProfilTidakDitemukanPage();

                // REDIRECT BERDASARKAN ROLE
                if (userData['role'] == 'admin') {
                  return const DashboardAdminWeb();
                }

                // CEK VERIFIKASI EMAIL — hanya mitra; admin sudah lolos di atas
                if (!snapshot.data!.emailVerified) {
                  return const EmailVerificationPage();
                }

                return const HalamanNavigasi();
              },
            );
          }
          return const LoginPage();
        },
      ),
    );
  }
}

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
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        var userData = snapshot.data!.data() as Map<String, dynamic>?;
        if (userData == null) {
          return const ProfilTidakDitemukanPage();
        }

      

        // AMBIL DATA LIST DARI FIRESTORE
        List<Map<String, dynamic>> dbSiklus =
            List<Map<String, dynamic>>.from(userData['siklus'] ?? []);
        List<Map<String, dynamic>> dbPanen =
            List<Map<String, dynamic>>.from(userData['panen'] ?? []);
        List<Map<String, dynamic>> dbBatch =
            List<Map<String, dynamic>>.from(userData['batch'] ?? []);

        // DEFINISI HALAMAN MENU
        final List<Widget> halaman = [
          // MENU 1: INPUT DATA
          MenuSatu(
  nomorTrayOtomatis: userData['counterTray'] ?? 1,
  namaMitra: userData['nama'] ?? "Mitra",
  onTambahBanyakData: (daftarTray) async {
    final int counterAwal = userData['counterTray'] ?? 1;
    final List<Map<String, dynamic>> trayBaru = [];

    for (int i = 0; i < daftarTray.length; i++) {
      final item = daftarTray[i];
      trayBaru.add({
        "peternak": userData['nama'] ?? "Mitra",
        "nama": "Tray ${counterAwal + i}",
        "beratTelur": item['beratTelur'],
        "tanggalMulai": item['tanggalMulai'],
        "cekM1": null,
        "cekM2": null,
      });
    }

    dbSiklus.addAll(trayBaru);

    // SATU write ke Firestore buat semua tray — anti race condition
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'siklus': dbSiklus,
      'counterTray': counterAwal + daftarTray.length,
    });
  },
),
          // MENU 2: PANTAU (Logika 0-5, 6-13, 14-20 & Auto Panen/Mati)
          MenuDua(
            daftarSiklus: dbSiklus,
            onKonfirmasiSehat: (index, minggu) {
              dbSiklus[index]['cekM$minggu'] = DateTime.now().toIso8601String();
              FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                'siklus': dbSiklus,
              });
            },
            onPanenOtomatis: (index, dataPanen) {
              dbPanen.add(dataPanen);
              dbSiklus.removeAt(index);
              FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                'siklus': dbSiklus,
                'panen': dbPanen,
              });
            },
            onGagalKePanen: (index, dataGagal) {
              dbPanen.add(dataGagal);
              dbSiklus.removeAt(index);
              FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                'siklus': dbSiklus,
                'panen': dbPanen,
              });
            },
          ),

          // MENU 3: VERIFIKASI (Kamera + Berdiam Diri + Bungkus)
         MenuTiga(
  daftarPanen: dbPanen,
  onBungkusBatch: (paketBatch) async {
    // 1. Ambil daftar nama tray yang baru saja dibungkus
    final List<dynamic> detailTrays = paketBatch['detailTrays'] ?? [];
    final Set<String> namaTraySelesai =
        detailTrays.map((t) => t['nama'].toString()).toSet();

    // 2. Buang tray yang sudah dibungkus dari dbPanen (Sisa antrean)
    final sisaPanen = dbPanen
        .where((item) => !namaTraySelesai.contains(item['nama'].toString()))
        .toList();

    // 3. AMBIL KODE BATCH SEBAGAI ID DOKUMEN (Contoh: BATCH-241023-143000)
    final String batchKode = paketBatch['batchKode'] ?? 
        "BATCH-${DateTime.now().millisecondsSinceEpoch}";

    // 4. GUNAKAN FIRESTORE WRITE BATCH (Simpan atomik tanpa resiko corrupt)
    final firestore = FirebaseFirestore.instance;
    final batchWrite = firestore.batch();

    // 👉 A. Simpan paket batch LENGKAP (termasuk foto Base64 untuk Excel) ke SUB-KOLEKSI
    final docBatchRef = firestore
        .collection('users')
        .doc(user.uid)
        .collection('batches') // 📁 Sub-koleksi khusus riwayat batch
        .doc(batchKode);

    batchWrite.set(docBatchRef, paketBatch);

    // 👉 B. Buat Ringkasan Super Ringan KHUSUS jika Menu 4 membaca dari dokumen User
    // (Foto Base64 dibuang dari sini agar dokumen User HP tetap ringan & < 1 MB)
    final ringkasanMenuEmpat = {
      'batchKode': batchKode,
      'tanggalBungkus': paketBatch['tanggalBungkus'],
      'tanggalFormatted': paketBatch['tanggalFormatted'],
      'totalBeratKg': paketBatch['totalBeratKg'],
      'jumlahTray': paketBatch['jumlahTray'],
      'status': paketBatch['status'],
      // HANYA simpan nama tray, JANGAN bawa fotoBase64 ke dokumen user
      'daftarNamaTray': detailTrays.map((e) => e['nama']).toList(),
    };

    // 👉 C. Update dokumen utama User
    final docUserRef = firestore.collection('users').doc(user.uid);
    batchWrite.update(docUserRef, {
      'panen': sisaPanen, // Antrean berkurang akurat
      'batch': FieldValue.arrayUnion([ringkasanMenuEmpat]), // Ringkasan ringan untuk Menu 4
    });

    // 🚀 EKSEKUSI SEKALIGUS (Anti Gagal & Bebas Error 'invalid-argument')
    await batchWrite.commit();
  },
   onUpdateFotoBatch: (batchKode, detailTraysTerbaru) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('batches')
        .doc(batchKode)
        .update({'detailTrays': detailTraysTerbaru});
  },
), 

          // MENU 4: RIWAYAT
          MenuEmpat(
            daftarBatch: dbBatch,
            onHapusBatchManual: (index) {
              dbBatch.removeAt(index);
              FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                'batch': dbBatch,
              });
            },
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
