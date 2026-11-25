// auth_service.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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
      final DocumentSnapshot userDoc =
          await _db.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        // Akun Auth ada di Firebase Auth, tetapi dokumen Firestore sudah
        // dihapus oleh Admin di page_kelola_mitra. Paksa logout seketika!
        await _auth.signOut();
        return "Akun Anda sudah tidak terdaftar atau telah dinonaktifkan oleh Admin.";
      }

      final Map<String, dynamic>? data = userDoc.data() as Map<String, dynamic>?;
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
      await _db.collection('users').doc(res.user!.uid).set({
        'nama': nama.trim(),
        'email': email.trim(),
        'role': 'mitra',
        'counterTray': 1,
        'siklus': [],
        'panen': [],
        'batch': [],
      });
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

  // ============================================================
  // FITUR ADMIN: MEMBUAT AKUN MITRA BARU
  // ────────────────────────────────────────────────────────────
  // TEKNIK ROBUST: Pakai FIREBASE APP INSTANCE KEDUA (sementara).
  //   ✅ Admin tetap login (TIDAK ke-logout sama sekali)
  //   ✅ TIDAK PERLU simpan password admin di mana pun
  //   ✅ Instance kedua langsung dihapus setelah selesai
  //   ✅ Cek role `admin` di Firestore TETAP dijalankan
  // ============================================================
  Future<String?> adminBuatAkunMitra(
      String emailMitra, String passwordMitra, String namaMitra) async {
    FirebaseApp? appSekunder;
    const namaAppSekunder = "MAGG_TEMP_CREATE_MITRA";
    try {
      final adminSaatIni = _auth.currentUser;
      if (adminSaatIni == null) return "Admin belum login.";

      // 1. Cek ROLE ADMIN di Firestore (sesuai settingan Firebase Anda)
      final adminDoc =
          await _db.collection('users').doc(adminSaatIni.uid).get();
      final adminData = adminDoc.data();
      if (adminData == null || adminData['role'] != 'admin') {
        return "Hanya admin yang boleh menambah mitra.";
      }

      try {
        appSekunder = Firebase.app(namaAppSekunder);
      } catch (_) {
        appSekunder = await Firebase.initializeApp(
          name: namaAppSekunder,
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      final authSekunder = FirebaseAuth.instanceFor(app: appSekunder);

      // 3. Buat akun di AUTH (via instance kedua)
      final UserCredential res =
          await authSekunder.createUserWithEmailAndPassword(
        email: emailMitra.trim(),
        password: passwordMitra.trim(),
      );
      final String uidBaru = res.user!.uid;

      // 4. Kirim email verifikasi (via instance kedua)
      try {
        await res.user!.sendEmailVerification();
      } catch (_) {}

      // 5. Logout instansi kedua (sehingga app sekunder tidak punya sesi)
      try {
        await authSekunder.signOut();
      } catch (_) {}

      // 6. Tulis data user ke Firestore (pakai instance UTAMA)
      //    NOTE: Write via instance utama karena Admin (pemilik sesi)
      //    sudah login di instance itu, dan Rules Firestore
      //    akan memvalidasi permisi secara atomik.
      await _db.collection('users').doc(uidBaru).set({
        'nama': namaMitra.trim(),
        'email': emailMitra.trim(),
        'role': 'mitra',
        'counterTray': 1,
        'siklus': [],
        'panen': [],
        'batch': [],
        'terakhirResetCounter': FieldValue.serverTimestamp(),
        'dibuatOlehAdmin': adminSaatIni.uid,
        'tanggalDibuat': FieldValue.serverTimestamp(),
      });

      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        return "Email sudah terdaftar. Pakai email lain.";
      }
      if (e.code == 'weak-password') {
        return "Password terlalu lemah. Minimal 6 karakter.";
      }
      if (e.code == 'invalid-email') {
        return "Format email tidak valid.";
      }
      if (e.code == 'operation-not-allowed') {
        return "Email/password auth dinonaktifkan di Firebase Console.";
      }
      return "Gagal buat akun: ${e.message ?? e.code}";
    } on FirebaseException catch (e) {
      return "Terjadi kesalahan Firebase: ${e.message ?? e.code}";
    } catch (e) {
      return "Terjadi kesalahan: $e";
    } finally {
      // 7. BERSIHKAN instance kedua (WAJIB, agar tidak menumpuk memori)
      try {
        final app = Firebase.app(namaAppSekunder);
        await app.delete();
      } catch (_) {}
    }
  }
}