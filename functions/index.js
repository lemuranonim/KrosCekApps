// Mengimpor modul yang diperlukan dari Firebase
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { initializeApp } = require("firebase-admin/app");

// Inisialisasi Firebase Admin SDK
initializeApp();

exports.sendPushNotification = onDocumentCreated("notifications/{notificationId}", async (event) => {
  const notificationData = event.data.data();
  const title = notificationData.title;
  const body = notificationData.body;

  // --- MULAI PERUBAHAN DI SINI ---

  // Buat payload "Pesan Data" (BUKAN "Pesan Notifikasi")
  // Ini memastikan pesan akan diproses oleh aplikasi Flutter di background
  const payload = {
    data: {
      title: title,
      body: body,
      // Anda bisa menambahkan data lain di sini jika perlu
    },
    android: {
      // Atur prioritas ke "high" untuk membangunkan aplikasi dari mode doze
      priority: "high",
    },
    apns: {
      payload: {
        aps: {
          // Setting ini membantu memicu background handler di iOS
          "content-available": 1,
          // Suara notifikasi untuk iOS ditempatkan di sini
          sound: "notification_sound.caf",
        },
      },
    },
    topic: "all_users",
  };

  // --- SELESAI PERUBAHAN ---

  // Kirim notifikasi menggunakan payload baru
  try {
    // Gunakan send() untuk mengirim payload yang kompleks
    await getMessaging().send(payload);
    console.log("Pesan data berhasil dikirim ke topik 'all_users'");
  } catch (error) {
    console.error("Gagal mengirim pesan data:", error);
  }
});