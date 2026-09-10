const admin = require("firebase-admin");

const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});
const db = admin.firestore();

const HARI_AUTO_PANEN = 21;

async function jalankan() {
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
      const tglMulai = item.tanggalMulai && item.tanggalMulai._seconds
        ? new Date(item.tanggalMulai._seconds * 1000)
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
}

jalankan().catch((e) => {
  console.error(e);
  process.exit(1);
});