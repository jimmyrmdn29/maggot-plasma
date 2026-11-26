import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';


import '../firebase_options.dart';
import 'penyimpanan_pengguna.dart';

// ============================================================================
// PEMBUAT AKUN MITRA (ADMIN): PAKAI FIREBASE APP SEKUNDER
// ============================================================================
class PembuatAkunMitraAdmin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final PenyimpananPengguna _penyimpanan = PenyimpananPengguna();

  Future<String?> adminBuatAkunMitra(
      String emailMitra, String passwordMitra, String namaMitra) async {
    FirebaseApp? appSekunder;
    const namaAppSekunder = "MAGG_TEMP_CREATE_MITRA";
    try {
      final adminSaatIni = _auth.currentUser;
      if (adminSaatIni == null) return "Admin belum login.";

      // 1. Cek ROLE ADMIN di Firestore
      final isAdmin = await _penyimpanan.cekRoleAdmin(adminSaatIni.uid);
      if (!isAdmin) {
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

      // 5. Logout instansi kedua
      try {
        await authSekunder.signOut();
      } catch (_) {}

      // 6. Tulis data user ke Firestore (pakai instance UTAMA)
      await _penyimpanan.buatDokumenMitra(
        uid: uidBaru,
        nama: namaMitra,
        email: emailMitra,
        dibuatOleh: adminSaatIni.uid,
      );

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
      // 7. BERSIHKAN instance kedua (WAJIB)
      try {
        final app = Firebase.app(namaAppSekunder);
        await app.delete();
      } catch (_) {}
    }
  }
}
