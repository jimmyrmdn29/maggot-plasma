import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth_service.dart';

class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({super.key});

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> with WidgetsBindingObserver {
  final AuthService _auth = AuthService();
  Timer? _cekTimer;
  bool _kirimUlangLoading = false;
  DateTime? _kirimUlangBerikutnya;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cekStatusEmail();
    _cekTimer = Timer.periodic(const Duration(seconds: 3), (_) => _cekStatusEmail());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cekTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _cekStatusEmail();
    }
  }

  Future<void> _cekStatusEmail() async {
    await _auth.reloadUser();
  }

  Future<void> _kirimUlang() async {
    if (_kirimUlangBerikutnya != null && DateTime.now().isBefore(_kirimUlangBerikutnya!)) {
      final sisa = _kirimUlangBerikutnya!.difference(DateTime.now()).inSeconds;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Tunggu $sisa detik sebelum kirim ulang.")),
      );
      return;
    }

    setState(() => _kirimUlangLoading = true);
    final err = await _auth.resendVerificationEmail();
    if (!mounted) return;
    setState(() => _kirimUlangLoading = false);

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }

    setState(() => _kirimUlangBerikutnya = DateTime.now().add(const Duration(seconds: 60)));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Email verifikasi dikirim ulang. Cek inbox/spam.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? "-";

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        title: const Text("Verifikasi Email"),
        actions: [
          IconButton(
            onPressed: () => _auth.logout(),
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
              Icon(Icons.mark_email_unread_outlined, size: 80, color: Colors.green[700]),
              const SizedBox(height: 20),
              const Text(
                "Silakan verifikasi email Anda di inbox!",
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
                "Setelah Anda klik tautan di email, aplikasi akan masuk sendiri. Tidak perlu login ulang.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  onPressed: _kirimUlangLoading ? null : _kirimUlang,
                  child: _kirimUlangLoading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text("KIRIM ULANG EMAIL"),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () => _auth.logout(),
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
