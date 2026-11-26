import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../backend/auth/autentikasi_pengguna.dart';
import '../login_page.dart';
import '../profil_tidak_ditemukan_page.dart';
import '../widget/app_header_mitra.dart';
import '../widget/loading_screen.dart';
import 'daftar_halaman_mitra.dart';
import 'item_navigasi.dart';

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
        if (!snapshot.hasData) return const LoadingScreen();

        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        if (userData == null) return const ProfilTidakDitemukanPage();

        final List<Widget> halaman = buatHalamanMitra(user: user, userData: userData);

        return Scaffold(
          appBar: AppHeaderMitra(
            namaMitra: userData['nama'] ?? 'Mitra',
            onLogout: () => AutentikasiPengguna().logout(),
          ),
          body: halaman[_indexMenu],
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _indexMenu,
            selectedItemColor: Colors.green[800],
            unselectedItemColor: Colors.grey,
            showUnselectedLabels: true,
            type: BottomNavigationBarType.fixed,
            onTap: (i) => setState(() => _indexMenu = i),
            items: itemNavigasiMitra,
          ),
        );
      },
    );
  }
}