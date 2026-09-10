const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

// Fungsi pembantu: cek apakah UID yang manggil adalah admin
async function pastikanAdmin(context) {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Hanya user terautentikasi yang dapat melakukan aksi ini."
    );
  }

  const callerDoc = await db.collection("users").doc(context.auth.uid).get();
  const callerData = callerDoc.data();

  if (!callerDoc.exists || !callerData || callerData.role !== "admin") {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Hanya admin yang boleh melakukan aksi ini."
    );
  }
}

// ==========================================================
// 1. HAPUS AKUN MITRA DARI FIREBASE AUTH (DIPANGGIL ADMIN)
// ==========================================================
exports.hapusUserAuth = functions.https.onCall(async (data, context) => {
  await pastikanAdmin(context); // <-- BARU: cek role admin dulu

  const uid = data.uid;
  if (!uid) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Parameter UID wajib disertakan."
    );
  }

  try {
    await admin.auth().deleteUser(uid);
    return { success: true, message: `User dengan UID: ${uid} berhasil dihapus dari Auth.` };
  } catch (error) {
    if (error.code === "auth/user-not-found") {
      return { success: true, message: "User sudah tidak ada di Auth." };
    }
    throw new functions.https.HttpsError("internal", error.message);
  }
});

// ==========================================================
// 2. AUTO-PANEN HARIAN (SCHEDULED, SERVER-SIDE)
// ==========================================================
const HARI_AUTO_PANEN = 21; // samain terus dengan app_config.dart di app

exports.autoPanenHarian = functions.pubsub
  .schedule("every 24 hours")
  .onRun(async (context) => {
    const usersSnap = await db.collection("users").where("role", "==", "mitra").get();

    const batch = db.batch();
    let adaPerubahan = false;

    usersSnap.forEach((doc) => {
      const data = doc.data();
      const siklus = data.siklus || [];
      const panen = data.panen || [];
      const sisaSiklus = [];
      let berubah = false;

      siklus.forEach((item) => {
        const tglMulai = item.tanggalMulai && item.tanggalMulai.toDate
          ? item.tanggalMulai.toDate()
          : new Date(item.tanggalMulai);
        const hari = Math.floor((Date.now() - tglMulai.getTime()) / (1000 * 60 * 60 * 24));

        if (hari >= HARI_AUTO_PANEN) {
          panen.push({ ...item, status: "SIAP PANEN" });
          berubah = true;
        } else {
          sisaSiklus.push(item);
        }
      });

      if (berubah) {
        batch.update(doc.ref, { siklus: sisaSiklus, panen: panen });
        adaPerubahan = true;
      }
    });

    if (adaPerubahan) await batch.commit();
    console.log("Auto-panen check selesai.");
    return null;
  });