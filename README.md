# KrosCek
_A smart app for QA professionals to manage field inspections efficiently._

**KrosCek** adalah solusi digital berbasis Flutter yang dirancang khusus untuk membantu divisi QA PT Advanta Indonesia dalam mengelola proses pelaporan inspeksi lapangan. Dengan KrosCek, pengguna dapat mencatat data secara real-time, memverifikasi informasi di lapangan, dan mengelola aktivitas QA dengan mudah melalui perangkat seluler.

Aplikasi ini dibangun untuk menyederhanakan tugas-tugas manual yang memakan waktu, meningkatkan akurasi data, dan menyediakan laporan yang terstruktur dengan integrasi penuh ke Google Sheets.

---

## Fitur Utama dan Alur Penggunaan

### 1. **Login Berbasis Peran**
- **Admin**:
  - Mengelola data aktivitas seluruh pengguna.
  - Mengirimkan notifikasi ke pengguna terkait tugas lapangan.
  - Melihat history perubahan data secara detail.
- **User (Field Inspector)**:
  - Mencatat inspeksi langsung dari lapangan.
  - Melaporkan absen log secara otomatis dengan geolokasi dan foto.
  - Memperbarui data inspeksi berdasarkan fase: Vegetative, Generative, Pre-Harvest, atau Harvest.

### 2. **Home Screen**
- Menampilkan informasi pengguna: nama, role, dan region.
- **Navigasi utama**:
  - Fase inspeksi (Vegetative, Generative, Pre-Harvest, Harvest).
  - Fitur Absen Log, Issue, dan Training.
- Fitur **filter** berdasarkan:
  - **Region**: Memilih wilayah kerja pengguna.
  - **QA SPV**: Supervisor QA terkait.
  - **District/FA**: Fokus data berdasarkan area spesifik.

### 3. **Pengelolaan Data Inspeksi**
- Sinkronisasi langsung dengan Google Sheets menggunakan Google Sheets API.
- **Fitur pencarian**:
  - Filter data berdasarkan QA SPV, District, atau kata kunci spesifik.
- **Halaman Detail**:
  - Menampilkan informasi inspeksi dalam bentuk tabel.
  - Formulir edit dengan komponen dinamis seperti dropdown, date picker, dan input angka.

### 4. **Absen Log**
- Pengguna dapat mencatat kehadiran dengan:
  - **Foto**: Diambil langsung melalui kamera.
  - **Lokasi**: Koordinat GPS otomatis.
  - **Waktu**: Waktu masuk otomatis saat absen dilakukan.
- Data dikirim ke Google Sheets dengan notifikasi sukses.

### 5. **Admin Dashboard**
- Melihat log aktivitas pengguna.
- Menelusuri history perubahan data inspeksi.
- Mengirimkan notifikasi atau tugas baru kepada pengguna.

### 6. **Peningkatan Performa**
- **Hive Cache**:
  - Menyimpan data sementara secara lokal untuk mempercepat akses.
- **Peta Interaktif**:
  - Menampilkan lokasi inspeksi dalam peta yang terhubung dengan Google Maps API.

### 7. **Analitik dan Pelaporan**
- Laporan dalam bentuk **chart** untuk memvisualisasikan tren inspeksi.
- Dashboard analitik untuk mengevaluasi data QA secara keseluruhan.

---

## Teknologi yang Digunakan

1. **Flutter**: Framework lintas platform untuk membangun aplikasi mobile.
2. **Google Sheets API**: Integrasi real-time dengan spreadsheet untuk menyimpan data inspeksi.
3. **Firebase Authentication**: Mengelola login berbasis peran dengan dukungan Google Sign-In.
4. **Hive**: Penyimpanan lokal untuk cache data.
5. **Google Maps API**: Menampilkan peta lokasi inspeksi.
6. **Lottie**: Animasi interaktif untuk loading dan splash screen.

---

## Use Case

### **Pengguna:**
- **Field Inspector (FI)**:
  - Memasukkan data inspeksi lapangan.
  - Melaporkan aktivitas absen secara otomatis.
- **Supervisor QA (QA SPV)**:
  - Memverifikasi data inspeksi.
  - Melacak aktivitas FI di lapangan.
- **Admin**:
  - Mengelola keseluruhan sistem.
  - Mengirimkan tugas dan memantau hasil pekerjaan.

### **Masalah yang Diatasi:**
1. **Pelaporan Manual**:
   - Mengurangi kesalahan data akibat metode input manual.
2. **Integrasi Data**:
   - Data lapangan langsung tersimpan di Google Sheets tanpa perlu rekap manual.
3. **Akses Data Real-time**:
   - Memungkinkan tim QA untuk memonitor progres lapangan kapan saja.
4. **Efisiensi Waktu**:
   - Menghemat waktu dengan otomatisasi absen dan pelaporan.

---

## Instalasi dan Konfigurasi

1. **Clone Repository**:
   ```bash
   git clone https://github.com/username/kroscek.git
   ```
2. **Masuk ke direktori proyek**:
   ```bash
   cd kroscek
   ```
3. **Instal dependensi**:
   ```bash
   flutter pub get
   ```
4. **Tambahkan kredensial API**:
   - **Google Sheets API**:
     - Aktifkan Google Sheets API di [Google Cloud Console](https://console.cloud.google.com/).
     - Tambahkan file `credentials.json` ke direktori proyek.
   - **Firebase**:
     - Konfigurasi Firebase Authentication untuk email/password dan Google Sign-In.

5. **Jalankan aplikasi**:
   ```bash
   flutter run
   ```

---

## Lisensi

**Hak Cipta Dilindungi**  
Seluruh kode sumber, dokumentasi, dan aset visual dalam repositori ini adalah milik pribadi. Tidak diperbolehkan untuk digunakan, dimodifikasi, didistribusikan, atau direproduksi tanpa izin tertulis dari pemilik proyek.  

**Copyright © 2024 LemurAnonimDev**

---

## Kontak

Untuk pertanyaan atau informasi lebih lanjut, silakan hubungi:  
- **Email**: mail@lemuranonimdev.com  
- **Telepon**: (+62) 821 4370 6440
