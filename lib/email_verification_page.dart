// email_verification_page.dart
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth_service.dart';

class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({super.key});

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage>
    with WidgetsBindingObserver {
  final AuthService _auth = AuthService();
  Timer? _cekTimer;
  Timer? _countdownTimer;

  bool _kirimUlangLoading = false;
  bool _isCheckingStatus = false;
  DateTime? _kirimUlangBerikutnya;
  int _sisaDetikCooldown = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cekStatusEmail();
    _mulaiPollingStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPollingStatus();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // =========================================================================
  // MANAJEMEN SIKLUS HIDUP APLIKASI (HEMAT BATERAI & SINKRONISASI WAKTU NYATA)
  // =========================================================================
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Sinkronkan sisa cooldown berdasarkan selisih jam sistem
      _updateSisaCooldownDariTarget();
      // Cek verifikasi seketika begitu user kembali dari Gmail
      _cekStatusEmail();
      _mulaiPollingStatus();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Hentikan timer background agar hemat baterai
      _stopPollingStatus();
    }
  }

  void _mulaiPollingStatus() {
    _cekTimer?.cancel();
    _cekTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _cekStatusEmail();
    });
  }

  void _stopPollingStatus() {
    _cekTimer?.cancel();
    _cekTimer = null;
  }

  Future<void> _cekStatusEmail() async {
    if (_isCheckingStatus) return; // Cegah overlapping network request

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _stopPollingStatus();
      return;
    }

    _isCheckingStatus = true;
    try {
      await _auth.reloadUser();
    } catch (_) {
    } finally {
      _isCheckingStatus = false;
    }
  }

  // Menghitung sisa detik secara presisi berdasarkan jam dinding perangkat
  void _updateSisaCooldownDariTarget() {
    if (_kirimUlangBerikutnya == null) {
      if (_sisaDetikCooldown != 0) {
        setState(() => _sisaDetikCooldown = 0);
      }
      return;
    }

    final sisa = _kirimUlangBerikutnya!.difference(DateTime.now()).inSeconds;
    if (sisa > 0) {
      setState(() => _sisaDetikCooldown = sisa);
    } else {
      setState(() {
        _sisaDetikCooldown = 0;
        _kirimUlangBerikutnya = null;
      });
      _countdownTimer?.cancel();
    }
  }

  // =========================================================================
  // KIRIM ULANG EMAIL & COUNTDOWN TIMER REAL-TIME
  // =========================================================================
  Future<void> _kirimUlang() async {
    // Validasi menggunakan DateTime agar akurat
    if (_kirimUlangBerikutnya != null &&
        DateTime.now().isBefore(_kirimUlangBerikutnya!)) {
      final sisa = _kirimUlangBerikutnya!.difference(DateTime.now()).inSeconds;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Tunggu $sisa detik sebelum kirim ulang."),
          backgroundColor: Colors.orange[800],
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _kirimUlangLoading = true);
    final err = await _auth.resendVerificationEmail();
    if (!mounted) return;
    setState(() => _kirimUlangLoading = false);

    if (err != null) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: Colors.red[800],
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Pasang cooldown target waktu 60 detik ke depan
    setState(() {
      _kirimUlangBerikutnya = DateTime.now().add(const Duration(seconds: 60));
      _sisaDetikCooldown = 60;
    });

    _mulaiCountdownTimer();

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                "Email verifikasi berhasil dikirim ulang! Cek folder inbox/spam.",
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _mulaiCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _updateSisaCooldownDariTarget();
    });
  }

  // =========================================================================
  // SAFETY LOGOUT CONFIRMATION
  // =========================================================================
  void _konfirmasiLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text(
              "Konfirmasi Keluar",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          "Apakah Anda yakin ingin keluar? Anda dapat masuk kembali setelah memverifikasi email.",
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("BATAL", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[800],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _auth.logout();
            },
            child: const Text("YA, KELUAR"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? "-";

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        title: const Text(
          "Verifikasi Email",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _konfirmasiLogout,
            icon: const Icon(Icons.logout_rounded),
            tooltip: "Keluar",
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.mark_email_unread_outlined,
                    size: 80,
                    color: Colors.green[700],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Silakan verifikasi email Anda di inbox!",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    email,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[800],
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Setelah Anda klik tautan di email, aplikasi akan masuk sendiri secara otomatis. Tidak perlu login ulang.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 1,
                    ),
                    onPressed: (_kirimUlangLoading || _sisaDetikCooldown > 0)
                        ? null
                        : _kirimUlang,
                    child: _kirimUlangLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _sisaDetikCooldown > 0
                                ? "KIRIM ULANG EMAIL ($_sisaDetikCooldown s)"
                                : "KIRIM ULANG EMAIL",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red[700],
                      side: BorderSide(color: Colors.red.shade200),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _konfirmasiLogout,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text(
                      "KELUAR",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
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