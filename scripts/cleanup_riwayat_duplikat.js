/*
 * cleanup_riwayat_duplikat.js
 *
 * Bersihkan batch duplikat di collection "users" sekali jalan.
 *
 * Yang dibersihkan:
 *   - item di field "batch" yang punya kumpulan nama tray sama,
 *     tetapi batchKode/tanggal berbeda.
 *
 * Yang TIDAK disentuh:
 *   - field "panen" (kecuali --clean-panen)
 *   - dokumen user
 *   - riwayat admin secara langsung (riwayat admin baca "batch")
 *
 * Cara pakai:
 *   cd functions
 *   set FIREBASE_SERVICE_ACCOUNT=<isi JSON service account>
 *   node ../scripts/cleanup_riwayat_duplikat.js                 # dry-run
 *   node ../scripts/cleanup_riwayat_duplikat.js --apply         # tulis perubahan
 *   node ../scripts/cleanup_riwayat_duplikat.js --apply --uid=UID_MITRA
 *   node ../scripts/cleanup_riwayat_duplikat.js --apply --clean-panen
 *
 * Catatan:
 *   - Key service account dipakai lokal saja, jangan commit.
 *   - Backup JSON ditulis sebelum --apply.
 *   - Default dry-run tidak mengubah Firestore.
 */

const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");

if (!process.env.FIREBASE_SERVICE_ACCOUNT) {
  console.error("ERROR: env FIREBASE_SERVICE_ACCOUNT belum diisi.");
  process.exit(1);
}

const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});
const db = admin.firestore();

const APPLY = process.argv.includes("--apply");
const CLEAN_PANEN = process.argv.includes("--clean-panen");
const UID_FILTER = (process.argv.find((arg) => arg.startsWith("--uid=")) || "").split("=")[1] || "";

function toIso(value) {
  if (!value) return null;
  if (typeof value.toDate === "function") return value.toDate().toISOString();
  if (value._seconds !== undefined) return new Date(value._seconds * 1000).toISOString();
  if (value instanceof Date) return value.toISOString();
  return String(value);
}

function extractNames(item) {
  const names = [];
  if (Array.isArray(item.daftarNamaTray)) {
    item.daftarNamaTray.forEach((name) => names.push(String(name).trim().toLowerCase()));
  }
  if (Array.isArray(item.detailTrays)) {
    item.detailTrays.forEach((detail) => {
      if (detail && detail.nama != null) names.push(String(detail.nama).trim().toLowerCase());
    });
  }
  if (item.nama != null) names.push(String(item.nama).trim().toLowerCase());
  return [...new Set(names)];
}

function groupKey(item) {
  return extractNames(item).sort().join("|");
}

function fotoCount(item) {
  if (!Array.isArray(item.detailTrays)) return 0;
  return item.detailTrays.filter((detail) => detail && detail.fotoUrl).length;
}

function batchTime(item) {
  const time = toIso(item.tanggalBungkus);
  return time ? new Date(time).getTime() : 0;
}

function summarize(item) {
  return {
    batchKode: item.batchKode || null,
    nama: item.nama || null,
    daftarNamaTray: item.daftarNamaTray || null,
    jumlahTray: item.jumlahTray || null,
    tanggalBungkus: toIso(item.tanggalBungkus),
    fotoCount: fotoCount(item),
  };
}

function replacer(key, value) {
  if (value && typeof value.toDate === "function") return value.toDate().toISOString();
  if (value && value._seconds !== undefined && value._nanoseconds !== undefined) {
    return new Date(value._seconds * 1000).toISOString();
  }
  return value;
}

async function main() {
  console.log(APPLY ? "MODE: APPLY" : "MODE: DRY-RUN");
  if (UID_FILTER) console.log("FILTER UID:", UID_FILTER);
  if (CLEAN_PANEN) console.log("CLEAN PANEN: aktif");

  const usersSnap = await db.collection("users").get();
  const backup = [];
  let totalUsers = 0;
  let totalGroups = 0;
  let totalRemoved = 0;
  let totalPanenRemoved = 0;

  for (const doc of usersSnap.docs) {
    if (UID_FILTER && doc.id !== UID_FILTER) continue;

    const data = doc.data() || {};
    const batchArr = Array.isArray(data.batch) ? data.batch : [];
    if (batchArr.length === 0) continue;

    const groups = new Map();
    batchArr.forEach((item, index) => {
      const key = groupKey(item);
      if (!groups.has(key)) groups.set(key, []);
      groups.get(key).push({ item, index });
    });

    const keepIndex = new Set();
    let changed = false;
    let removedHere = 0;

    for (const [key, items] of groups.entries()) {
      if (items.length <= 1) {
        items.forEach((entry) => keepIndex.add(entry.index));
        continue;
      }

      let keeper = 0;
      let bestFoto = fotoCount(items[0].item);
      let bestTime = batchTime(items[0].item);

      for (let i = 1; i < items.length; i++) {
        const currentFoto = fotoCount(items[i].item);
        const currentTime = batchTime(items[i].item);
        if (currentFoto > bestFoto || (currentFoto === bestFoto && currentTime < bestTime)) {
          keeper = i;
          bestFoto = currentFoto;
          bestTime = currentTime;
        }
      }

      items.forEach((entry, i) => {
        if (i === keeper) keepIndex.add(entry.index);
      });

      changed = true;
      totalGroups++;
      totalRemoved += items.length - 1;
      removedHere += items.length - 1;

      console.log("");
      console.log(`[DUP] user=${doc.id} nama=${data.nama || "-"}`);
      console.log(`      key=${key}`);
      console.log(`      jumlah=${items.length} hapus=${items.length - 1}`);
      console.log(`      pertahankan=${items[keeper].item.batchKode || items[keeper].item.nama || "-"}`);
      items.forEach((entry, i) => {
        if (i !== keeper) console.log(`      hapus=${entry.item.batchKode || entry.item.nama || "-"}`);
      });
    }

    if (!changed) continue;

    const newBatch = batchArr.filter((item, index) => keepIndex.has(index));
    totalUsers++;

    const keptNames = new Set();
    newBatch.forEach((item) => extractNames(item).forEach((name) => keptNames.add(name)));

    let newPanen = Array.isArray(data.panen) ? data.panen : [];
    let panenRemoved = 0;
    if (CLEAN_PANEN) {
      const beforePanen = newPanen.length;
      newPanen = newPanen.filter((item) => {
        const names = extractNames(item);
        return !names.some((name) => keptNames.has(name));
      });
      panenRemoved = beforePanen - newPanen.length;
      totalPanenRemoved += panenRemoved;
    }

    backup.push({
      uid: doc.id,
      nama: data.nama || null,
      removedBatchCount: removedHere,
      removedPanenCount: panenRemoved,
      beforeBatch: batchArr.map(summarize),
      afterBatch: newBatch.map(summarize),
    });

    if (APPLY) {
      const update = { batch: newBatch };
      if (CLEAN_PANEN) update.panen = newPanen;
      await doc.ref.update(update);
      console.log(`[APPLY] user=${doc.id} batch ${batchArr.length} -> ${newBatch.length}, panen removed=${panenRemoved}`);
    } else {
      console.log(`[DRY-RUN] user=${doc.id} batch ${batchArr.length} -> ${newBatch.length}, panen removed=${panenRemoved}`);
    }
  }

  if (backup.length > 0) {
    const stamp = new Date().toISOString().replace(/[:.]/g, "-");
    const backupFile = path.join(process.cwd(), `backup_riwayat_duplikat_${stamp}.json`);
    fs.writeFileSync(backupFile, JSON.stringify(backup, replacer, 2));
    console.log("");
    console.log("Backup ditulis:", backupFile);
  }

  console.log("");
  console.log("RINGKASAN:");
  console.log("  user berubah:", totalUsers);
  console.log("  grup duplikat:", totalGroups);
  console.log("  batch dihapus:", totalRemoved);
  console.log("  panen dihapus:", totalPanenRemoved);
  console.log(APPLY ? "  status: APPLY selesai" : "  status: DRY-RUN, belum ada perubahan Firestore");
}

main().catch((error) => {
  console.error("ERROR:", error);
  process.exit(1);
});
