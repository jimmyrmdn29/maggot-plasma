import 'package:firebase_auth/firebase_auth.dart';

import 'penyimpanan_pengguna.dart';

// ============================================================================
// AUTENTIKASI PENGGUNA: LOGIN, LOGOUT, RELOAD, VERIFIKASI EMAIL
// ============================================================================
class AutentikasiPengguna {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final PenyimpananPengguna _penyimpanan = PenyimpananPengguna();

  // userChanges ikut terpicu saat user.reload() (emailVerified berubah).
  // authStateChanges hanya login/logout, makanya layar verifikasi bisa terkunci.
  Stream<User?> get userStream => _auth.userChanges();

  // ============================================================
  // LOGIN DENGAN PROTEKSI GHOST USER & FRIENDLY ERROR
  // ============================================================
  Future<String?> loginEmail(String email, String pass) async {
    final String cleanEmail = email.trim();
    final String cleanPass = pass.trim();

    if (cleanEmail.isEmpty || cleanPass.isEmpty) {
      return "Email dan password wajib diisi.";
    }

    try {
      final UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: cleanPass,
      );

      final User? user = cred.user;
      if (user == null) {
        return "Pengguna tidak ditemukan.";
      }

      // ──────────────────────────────────────────────────────────
      // PROTEKSI GHOST USER (CEGAH MITRA YANG SUDAH DIHAPUS MASUK)
      // ──────────────────────────────────────────────────────────
      final doc = await _penyimpanan.ambilDokumenUser(user.uid);

      if (!doc.exists) {
        // Akun Auth ada di Firebase Auth, tetapi dokumen Firestore sudah
        // dihapus oleh Admin di page_kelola_mitra. Paksa logout seketika!
        await _auth.signOut();
        return "Akun Anda sudah tidak terdaftar atau telah dinonaktifkan oleh Admin.";
      }

      final Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
      if (data == null) {
        await _auth.signOut();
        return "Data akun tidak valid. Hubungi Admin.";
      }

      return null; // Login sukses
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return "Akun dengan email ini tidak ditemukan.";
        case 'wrong-password':
        case 'invalid-credential':
          return "Email atau password yang Anda masukkan salah.";
        case 'user-disabled':
          return "Akun ini telah dinonaktifkan oleh sistem.";
        case 'too-many-requests':
          return "Terlalu banyak percobaan gagal. Silakan coba beberapa saat lagi.";
        case 'invalid-email':
          return "Format email tidak valid.";
        case 'network-request-failed':
          return "Gagal terhubung. Periksa koneksi internet Anda.";
        default:
          return "Gagal masuk: ${e.message ?? e.code}";
      }
    } on FirebaseException catch (e) {
      return "Kesalahan database: ${e.message ?? e.code}";
    } catch (e) {
      return "Terjadi kesalahan tidak terduga: $e";
    }
  }

  // ============================================================
  // DAFTAR (Self-register ditutup utk Mitra Kontrak)
  // Dipertahankan sesuai aturan backward-compatibility
  // ============================================================
  Future<String?> registerEmail(String email, String pass, String nama) async {
    try {
      UserCredential res = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: pass.trim(),
      );
      await _penyimpanan.buatDokumenUserBaru(res.user!.uid, nama: nama, email: email);
      await res.user!.sendEmailVerification();
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        return "Email sudah terdaftar. Gunakan email lain.";
      }
      if (e.code == 'weak-password') {
        return "Password terlalu lemah. Minimal 6 karakter.";
      }
      return e.message ?? e.code;
    } catch (e) {
      return e.toString();
    }
  }

  // LOGOUT
  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<void> reloadUser() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.reload();
    final refreshed = _auth.currentUser;
    // Paksa token refresh supaya userChanges terkirim setelah tautan email diklik.
    if (refreshed != null && refreshed.emailVerified) {
      await refreshed.getIdToken(true);
    }
  }

  Future<String?> resendVerificationEmail() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return "Sesi tidak ditemukan. Silakan login ulang.";
      await user.sendEmailVerification();
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
