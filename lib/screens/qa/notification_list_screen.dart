import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart'; // <-- [PERBAIKAN] Typo sudah diperbaiki
import 'package:shared_preferences/shared_preferences.dart';

class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({super.key});

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  DateTime? _lastViewTimestamp;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null).then((_) {
      _loadLastViewTimestamp();
    });
  }

  Future<void> _loadLastViewTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    final lastViewString = prefs.getString('lastNotificationViewTimestamp');

    if (mounted) {
      setState(() {
        if (lastViewString != null) {
          _lastViewTimestamp = DateTime.parse(lastViewString);
        }
      });
    }
  }

  Future<void> _markNotificationsAsRead() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    // Simpan waktu saat ini sebagai waktu terakhir melihat notifikasi
    await prefs.setString('lastNotificationViewTimestamp', now.toIso8601String());

    // Perbarui state agar UI langsung merefleksikan perubahan
    if (mounted) {
      setState(() {
        _lastViewTimestamp = now;
      });
    }
  }

  Future<void> _showNotificationDetailDialog(
      String title, dynamic body, DateTime? timestamp, bool isRichText) async {
    Widget contentWidget;

    // ... (kode untuk membuat contentWidget tidak berubah)
    if (isRichText) {
      try {
        var json = jsonDecode(body as String);
        final quillController = QuillController(
          document: Document.fromJson(json),
          selection: const TextSelection.collapsed(offset: 0),
        );
        final focusNode = FocusNode();
        final scrollController = ScrollController();

        // --- PERBAIKAN FINAL ---
        // Gunakan constructor QuillEditor() standar dan tambahkan
        // parameter readOnly secara langsung.
        contentWidget = QuillEditor(
          controller: quillController,
          scrollController: scrollController,
          focusNode: focusNode,
        );
        // --- PERBAIKAN SELESAI ---

      } catch (e) {
        contentWidget =
            Text(body.toString(), style: const TextStyle(height: 1.5));
      }
    } else {
      contentWidget =
          Text(body.toString(), style: const TextStyle(height: 1.5));
    }

    // Gunakan 'await' untuk menunggu dialog ditutup
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          title: Row(
            children: [
              Icon(Icons.label_important_outline, color: Colors.green[800]),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(title,
                      style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.4,
            child: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  contentWidget,
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.access_time,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        timestamp != null
                            ? DateFormat('EEEE, dd MMM yyyy, HH:mm', 'id_ID')
                            .format(timestamp)
                            : 'Waktu tidak tersedia',
                        style:
                        const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child:
              const Text('Tutup', style: TextStyle(color: Colors.green)),
              // Tombol ini sekarang hanya menutup dialog
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );

    // Kode ini akan dieksekusi setelah dialog ditutup
    // dengan cara apa pun (tombol 'Tutup' atau klik di luar).
    await _markNotificationsAsRead();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 4,
      ),
      backgroundColor: Colors.grey[50],
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.green));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Belum Ada Notifikasi',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          var docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var doc = docs[index];
              var data = doc.data() as Map<String, dynamic>;
              var title = data['title'] ?? 'Tanpa Judul';
              var body = data['body'] ?? 'Tanpa Isi';
              var timestamp = data['timestamp'] as Timestamp?;
              var isRichText = data['isRichText'] ?? false;

              // --- PENYESUAIAN UTAMA DIMULAI DI SINI ---
              String bodyPreview = body; // Defaultnya, tampilkan body asli

              if (isRichText) {
                try {
                  // Lakukan konversi dari JSON ke teks biasa
                  var json = jsonDecode(body);
                  final quillDoc = Document.fromJson(json);
                  bodyPreview = quillDoc.toPlainText().replaceAll('\n', ' ').trim();

                  // Beri teks placeholder jika hasilnya kosong
                  if (bodyPreview.isEmpty) {
                    bodyPreview = '[Pesan terformat]';
                  }
                } catch (e) {
                  // Fallback jika terjadi error
                  bodyPreview = '[Gagal memuat cuplikan]';
                }
              }
              // --- PENYESUAIAN SELESAI ---

              bool isUnread = false;
              if (timestamp != null && _lastViewTimestamp != null) {
                isUnread = timestamp.toDate().isAfter(_lastViewTimestamp!);
              } else if (timestamp != null && _lastViewTimestamp == null) {
                isUnread = true;
              }

              return Card(
                margin:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                elevation: 2.0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                color: isUnread ? Colors.white : Colors.grey[100],
                child: ListTile(
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  leading: CircleAvatar(
                    backgroundColor:
                    isUnread ? Colors.green : Colors.grey[300],
                    child: Icon(
                      Icons.notifications_active,
                      color: isUnread ? Colors.white : Colors.grey[600],
                    ),
                  ),
                  title: Text(
                    title,
                    style: TextStyle(
                      fontWeight:
                      isUnread ? FontWeight.bold : FontWeight.normal,
                      color: Colors.black87,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      bodyPreview, // <-- Gunakan variabel bodyPreview yang sudah bersih
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey[700],
                        // Gaya italic tidak diperlukan lagi
                        fontStyle: FontStyle.normal,
                      ),
                    ),
                  ),
                  trailing: Text(
                    timestamp != null
                        ? DateFormat('dd MMM, HH:mm').format(timestamp.toDate())
                        : '',
                    style:
                    const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  onTap: () {
                    _showNotificationDetailDialog(
                      title,
                      body, // body asli tetap dikirim ke dialog
                      timestamp?.toDate(),
                      isRichText,
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}