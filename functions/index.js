const functions = require('firebase-functions');
const admin = require('firebase-admin');
const xlsx = require('xlsx');
const { Storage } = require('@google-cloud/storage');
const os = require('os');
const path = require('path');
const fs = require('fs');

admin.initializeApp();
const storage = new Storage();

exports.processExcelFile = functions.storage.object().onFinalize(async (object) => {
  const bucketName = object.bucket;
  const filePath = object.name;
  const fileName = path.basename(filePath);
  const tempFilePath = path.join(os.tmpdir(), fileName);

  // Download file dari Firebase Storage
  await storage.bucket(bucketName).file(filePath).download({destination: tempFilePath});

  // Membaca file Excel
  const workbook = xlsx.readFile(tempFilePath);
  const sheetName = workbook.SheetNames[0];
  const sheet = workbook.Sheets[sheetName];
  const data = xlsx.utils.sheet_to_json(sheet);

  // Proses data yang diambil dari file Excel (misalnya, simpan ke Firestore)
  const db = admin.firestore();
  const batch = db.batch();

  data.forEach((row) => {
    const docRef = db.collection('excelData').doc();  // Ganti 'excelData' dengan koleksi yang diinginkan
    batch.set(docRef, row);
  });

  await batch.commit();

  // Hapus file sementara
  fs.unlinkSync(tempFilePath);

  console.log(`Processed file: ${fileName}`);
});
