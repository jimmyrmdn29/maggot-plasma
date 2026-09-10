//login_page.dart
import 'package:flutter/material.dart';
import 'auth_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// CATATAN PENTING (UNTUK MITRA KONTRAK):
//   Self-register (daftar sendiri) DINONAKTIFKAN dengan sengaja.
//   Mengingat aplikasi ini untuk MITRA KONTRAK (bukan mitra lepas),
//   maka akun mitra HANYA BOLEH DIBUATKAN oleh ADMIN setelah ada
//   penandatanganan kontrak / perjanjian kerjasama.
//
//   Cara buat akun mitra:
//     1. Login sebagai ADMIN
//     2. Buka tab "KELOLA MITRA"
//     3. Isi nama, email, password mitra → klik TAMBAH
//     4. Mitra menerima email verifikasi (cek spam jika tidak ada)
//     5. Setelah verifikasi, mitra bisa login di sini.
// ═══════════════════════════════════════════════════════════════════════════

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: SizedBox(
            width: 420,
            child: Column(
              children: [
               Image.asset(
              'assets/images/logo.png',
              height: 120,
              width: 120,
              fit: BoxFit.contain, // Biar logonya proporsional & gak gepeng
            ),
                const SizedBox(height: 10),
                const Text("Login",
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green)),
                const SizedBox(height: 8),
                Text(
                  "Aplikasi Mitra Kontrak Budidaya Maggot",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                        labelText: "Email", border: OutlineInputBorder())),
                const SizedBox(height: 15),
                TextField(
                    controller: _passController,
                    decoration: const InputDecoration(
                        labelText: "Password", border: OutlineInputBorder()),
                    obscureText: true),
                const SizedBox(height: 30),
                loading
                    ? const CircularProgressIndicator()
                    : SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green),
                          onPressed: () async {
                            setState(() => loading = true);
                            String? err = await AuthService().loginEmail(
                                _emailController.text, _passController.text);
                            if (mounted) {
                              if (err != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(err)));
                              }
                              setState(() => loading = false);
                            }
                          },
                          child: const Text("MASUK",
                              style: TextStyle(color: Colors.white)),
                        ),
                      ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Belum punya akun?\nAkun mitra hanya dibuatkan oleh Admin setelah penandatanganan kontrak kerjasama. Hubungi admin untuk pendaftaran.",
                          style:
                              TextStyle(fontSize: 12, color: Color(0xFF0D47A1)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}