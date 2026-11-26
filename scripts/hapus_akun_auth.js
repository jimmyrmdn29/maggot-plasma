/* ============================================================
 * hapus_akun_auth.js
 *
 * Worker untuk queue "akun_auth_perlu_dihapus".
 *
 * Alur aplikasi:
 *   1. Admin hapus mitra di aplikasi.
 *   2. PenyimpananMitra.hapusMitra() menulis dokumen
 *      akun_auth_perlu_dihapus/<uid>, lalu menghapus users/<uid>.
 *   3. Worker ini membaca queue dan menghapus user dari
 *      Firebase Authentication.
 *
 * Cara pakai lokal:
 *   set FIREBASE_SERVICE_ACCOUNT=<isi JSON service account>
 *   node scripts/hapus_akun_auth.js            # proses queue
 *   node scripts/hapus_akun_auth.js --dry-run  # hanya tampilkan queue
 *
 * Di GitHub Actions, secret FIREBASE_SERVICE_ACCOUNT dipakai.
 * Jangan commit file service account ke repo.
 * ============================================================ */

const admin = require("firebase-admin");

if (!process.env.FIREBASE_SERVICE_ACCOUNT) {
  console.error("ERROR: env FIREBASE_SERVICE_ACCOUNT belum diisi.");
  process.exit(1);
}

const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();
const DRY_RUN = process.argv.includes("--dry-run");

async function main() {
  console.log(DRY_RUN ? "MODE: DRY-RUN" : "MODE: APPLY");

  const queueSnap = await db.collection("akun_auth_perlu_dihapus").get();
  console.log(`Queue ditemukan: ${queueSnap.size} dokumen`);

  let total = 0;
  let deletedAuth = 0;
  let alreadyAbsent = 0;
  let queueDeleted = 0;
  let failed = 0;

  for (const doc of queueSnap.docs) {
    total++;
    const uid = doc.id;
    const data = doc.data() || {};
    const nama = data.nama || "-";

    console.log(`\n[QUEUE] uid=${uid} nama=${nama}`);

    if (DRY_RUN) {
      console.log("[DRY-RUN] tidak menghapus Auth / queue");
      continue;
    }

    try {
      await admin.auth().deleteUser(uid);
      deletedAuth++;
      console.log(`[AUTH] uid=${uid} berhasil dihapus`);
    } catch (error) {
      if (error.code === "auth/user-not-found") {
        alreadyAbsent++;
        console.log(`[AUTH] uid=${uid} sudah tidak ada, dianggap selesai`);
      } else {
        failed++;
        console.error(`[AUTH] GAGAL uid=${uid}: ${error.code || ""} ${error.message}`);
        try {
          await doc.ref.set(
            {
              error: error.message,
              errorCode: error.code || null,
              dicobaPada: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
        } catch (updateError) {
          console.error(`[QUEUE] gagal menulis error uid=${uid}: ${updateError.message}`);
        }
        continue;
      }
    }

    try {
      await doc.ref.delete();
      queueDeleted++;
      console.log(`[QUEUE] uid=${uid} dihapus dari queue`);
    } catch (error) {
      failed++;
      console.error(`[QUEUE] GAGAL hapus queue uid=${uid}: ${error.message}`);
    }
  }

  console.log("\nRINGKASAN:");
  console.log(`  total queue     : ${total}`);
  console.log(`  auth dihapus    : ${deletedAuth}`);
  console.log(`  sudah tidak ada : ${alreadyAbsent}`);
  console.log(`  queue dihapus   : ${queueDeleted}`);
  console.log(`  gagal           : ${failed}`);
  console.log(DRY_RUN ? "  status          : DRY-RUN, tidak ada perubahan" : "  status          : APPLY selesai");

  if (failed > 0) {
    process.exit(1);
  }
}

main().catch((error) => {
  console.error("ERROR:", error);
  process.exit(1);
});