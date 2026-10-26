# Planning audit dan Coverage mingguan

## Alur

- Menu kalender pada layar QA atau tombol **Planning Vege / PH / H** di Coverage membuka planning audit.
- Planning memiliki tab Vegetative, PreHarvest, Harvest; Detasseling yang sudah ada tetap terpisah.
- Kelompok planning langsung desa, dengan identitas region + kabupaten + kecamatan + desa. Codet dan hybrid tidak memecah kelompok.
- Rentang planning adalah jendela audit yang tersedia, bukan penugasan atau jadwal yang disimpan ke database.
- Minggu dipilih dalam rentang Senin–Minggu. Planning default minggu depan; Coverage default minggu berjalan.
- Proyeksi Senin–Minggu memakai seluruh irisan jendela On Going DAP. `plannedDate` adalah hari pertama lahan eligible, bukan satu-satunya hari lahan dapat dipilih. Ringkasan harian dan daftar hasil filter memakai sumber target yang sama.

## Target dan achievement

- Pada **Target Audit**, target adalah fase dengan jendela **On Going** DAP yang beririsan dengan minggu terpilih. **All Coverage** mencakup fase yang jendela targetnya sudah dimulai sampai minggu terpilih. Aturan menggunakan `DapHelper`, termasuk SC dataran tinggi dan PSP. PSP tidak memiliki PreHarvest.
- Tanggal tanam memakai revisi audit yang valid, lalu tanggal master sebagai fallback. Tanggal kosong/tidak valid tidak menghasilkan target.
- Audit fase yang sudah selesai sebelum awal minggu tidak ditargetkan ulang. Backlog di luar jendela DAP tidak dimasukkan ke target minggu lain.
- Completion memakai audit bertanggal sampai hari ini. Audit terlambat dapat menutup target minggu sebelumnya. PSP Vegetative membutuhkan empat pass; PSP Generative membutuhkan dua pass, dengan dukungan data lama yang hanya memiliki tanggal selesai fase.
- Overdue berarti target belum selesai dan batas akhir jendela audit/minggu sudah terlewati.
- Angka luas memakai `effective_area_ha`. Nilai negatif/tidak valid dianggap nol.
- Total target, komposisi, dan Stage menghitung satu lahan sekali meski beberapa checkpoint jatuh pada minggu yang sama. Achievement ha dihitung jika seluruh target lahan pada lingkup tersebut selesai. Skor achievement/rating memakai bobot fase dan completion, bukan luas ha; luas target dan selesai tetap ditampilkan terpisah.
- Per-fase Generative juga menghitung luas lahan sekali; semua checkpoint Generative yang menjadi target pada minggu tersebut harus selesai.

## Kondisi dan filter

- Flagging, NC, crop monitoring, dan male chopping memakai nilai audit terbaru yang tersedia sampai hari ini untuk lahan yang masuk lingkup target terpilih.
- Flagging mengikuti urutan tanggal audit dan fase. PLD lama tidak mengalahkan flagging yang lebih baru. Kode action `D` (Monitor) tidak dianggap sebagai decision `D` (Discard).
- **Status audit** terpisah dari **Komposisi flagging**. **Belum Audit** berarti masih ada target audit yang belum selesai, termasuk pass/checkpoint parsial. **Selesai Audit** berarti seluruh target pada lingkup terpilih sudah selesai. Keduanya memakai tanggal/completion audit, bukan flagging, dan menyediakan detail FN masing-masing.
- Pada **All Coverage + All Phase**, komposisi memakai flagging terakhir yang valid lintas fase target. GF dari Vegetative tidak membuktikan audit Harvest sudah selesai. Pemilihan fase membatasi flagging dan status audit ke fase itu; Target Audit memakai target minggu yang dipilih.
- Flag yang dikenali adalah GF, RFI, RFD, BF, dan PLD. BF juga tersedia di filter dan tidak boleh berubah menjadi kategori kosong atau mempertahankan GF yang lebih lama.
- Nilai kosong diberi label **Belum Flagging** (`Not Yet Flagging` tetap menjadi nilai internal filter). Kategori ini berarti belum ada flag valid dalam lingkup terpilih, bukan belum diaudit. Audit CP1/CP2 dapat selesai tanpa menghasilkan flag.
- Kategori GF/RFI/RFD/BF/Belum Flagging yang terpilih tetap ditampilkan saat bernilai 0 ha. Kategori yang sengaja dimatikan melalui filter tidak ditampilkan. Pilihan kosong menghasilkan dashboard kosong dengan persentase nol.
- PLD/discard tidak menghasilkan target operasional dan dikecualikan dari komposisi ini; layar menjelaskan pengecualiannya. Filter flagging berlaku ke seluruh ringkasan, status audit, rating, struktur wilayah, dan detail; persentase dihitung ulang dari ha yang tersisa.
- NC Roguing: Not Yet / On Going; LSV: Low / Moderate / High atau temuan PSP `>0`; isolasi: Yes. Satu lahan dapat masuk beberapa indikator NC.
- CU/CH oke: Fair, Good, Best. Male chopping Done: Complete/Done. Indikator menampilkan ha yang memiliki data agar nilai kosong tidak dianggap baik atau selesai. Persentase indikator menggunakan seluruh ha target terfilter; persentase NC tidak harus berjumlah 100%.
- Stage adalah Vegetative, Generative, PreHarvest, Harvest berdasarkan DAP **akhir minggu**. Komposisinya tidak tumpang tindih.

## Batas data dan akses

- Batas akses region/season/FI/SPV tetap menggunakan provider dan aturan akses yang sudah ada. Route planning mengikuti hak akses Planning Detasseling; data role yang dibatasi tidak diambil dari sumber global alternatif.
- Query Coverage memuat kolom metrik yang diperlukan, tanpa mengambil seluruh kolom audit atau mengubah database.
- Tampilan minggu lampau merupakan proyeksi dari record audit yang masih tersedia, bukan snapshot historis immutable. Koreksi tanggal tanam/luas atau penggantian audit dapat mengubah hasil minggu lampau.
- `flagging_final` master tidak memiliki tanggal, sehingga hanya dipakai sebagai fallback pada minggu berjalan/mendatang, bukan minggu lampau.

## Verifikasi lokal

Jalankan `flutter test --no-pub test/weekly_audit_test.dart test/weekly_audit_widgets_test.dart`.

Test mencakup DAP, pergantian minggu, completion, filter PLD 95/3/2, BF lintas fase, pemisahan backlog audit dan flagging, checkpoint ganda, PSP parsial, kategori nol, pengelompokan desa, role, dan layout ponsel. Contoh regresi membedakan 100 ha belum audit Harvest dari 0,7 ha belum memiliki flag. Untuk menghasilkan pratinjau PNG, set `AUDIT_QA_CAPTURE=true` dan opsional `AUDIT_QA_FONT` ke font TTF lokal, lalu jalankan test widget. Output berada di `build/qa/weekly_coverage_mobile.png` dan `build/qa/flagging_audit_status_mobile.png`.

Pengujian menggunakan fixture lokal; tidak memvalidasi isi data atau skema Supabase produksi secara langsung.
