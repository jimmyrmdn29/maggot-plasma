import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth_service.dart';

class ProfilTidakDitemukanPage extends StatelessWidget {
  const ProfilTidakDitemukanPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? "-";
    final uid = user?.uid ?? "-";

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        title: const Text("Profil Tidak Ditemukan"),
        actions: [
          IconButton(
            onPressed: () => AuthService().logout(),
            icon: const Icon(Icons.logout_rounded),
            tooltip: "Keluar",
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off_outlined, size: 80, color: Colors.green[700]),
              const SizedBox(height: 20),
              const Text(
                "Profil tidak ditemukan",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                email,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              const Text(
                "Akun login sudah ada, tetapi data MAG di Firestore belum ada. "
                "Kalau dokumen users dibuat, layar ini akan berganti sendiri. "
                "Atau keluar lalu daftar ulang.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              SelectableText(
                "UID: $uid",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () => AuthService().logout(),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text("KELUAR"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
