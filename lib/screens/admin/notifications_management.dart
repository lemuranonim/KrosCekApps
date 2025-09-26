import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:go_router/go_router.dart';

class NotificationsManagementScreen extends StatefulWidget {
  const NotificationsManagementScreen({super.key});

  @override
  State<NotificationsManagementScreen> createState() =>
      _NotificationsManagementScreenState();
}

class _NotificationsManagementScreenState
    extends State<NotificationsManagementScreen> {
  final _titleController = TextEditingController();
  final QuillController _bodyController = QuillController.basic();
  final FocusNode _focusNode = FocusNode();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // Listen to changes in the document and selection
    _bodyController.addListener(() {
      // Ensure UI updates when formatting changes
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _sendNotification() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judul tidak boleh kosong!')),
      );
      return;
    }
    if (_bodyController.document.isEmpty()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi pesan tidak boleh kosong!')),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final bodyJson = jsonEncode(_bodyController.document.toDelta().toJson());

      await FirebaseFirestore.instance.collection('notifications').add({
        'title': _titleController.text,
        'body': bodyJson,
        'timestamp': FieldValue.serverTimestamp(),
        'isRichText': true,
      });

      _titleController.clear();
      _bodyController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notifikasi berhasil dikirim!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengirim notifikasi: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  // This properly toggles a format on and off
  void _toggleFormat(Attribute attribute) {
    // Get the current state of this attribute
    final style = _bodyController.getSelectionStyle();
    final isActive = style.attributes[attribute.key] != null;

    if (isActive) {
      // If active, we need to remove the attribute
      _bodyController.formatSelection(Attribute.clone(attribute, null));
    } else {
      // If not active, we add the attribute
      _bodyController.formatSelection(attribute);
    }

    // Force UI update after format change
    setState(() {});
  }

  // Helper method to check if a format is active
  bool _isFormatActive(Attribute attribute) {
    final style = _bodyController.getSelectionStyle();
    return style.attributes[attribute.key] != null;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSending,
      // ignore: deprecated_member_use
      onPopInvoked: (didPop) {
        if (didPop) return;
        context.go('/admin');
      },
      child: Scaffold(
        appBar: AppBar(
          elevation: 2,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _isSending ? null : () => context.go('/admin'),
          ),
          title: const Text(
            'Buat Notifikasi Baru',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                enabled: !_isSending,
                decoration: const InputDecoration(
                  labelText: 'Judul Notifikasi',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
              ),
              const SizedBox(height: 20),
              Text('Isi Pesan', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),

              // Custom formatting toolbar with true toggle functionality
              AbsorbPointer(
                absorbing: _isSending,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Bold button
                        _buildFormatButton(
                          icon: Icons.format_bold,
                          isActive: _isFormatActive(Attribute.bold),
                          onPressed: () => _toggleFormat(Attribute.bold),
                          tooltip: 'Bold',
                        ),
                        // Italic button
                        _buildFormatButton(
                          icon: Icons.format_italic,
                          isActive: _isFormatActive(Attribute.italic),
                          onPressed: () => _toggleFormat(Attribute.italic),
                          tooltip: 'Italic',
                        ),
                        // Underline button
                        _buildFormatButton(
                          icon: Icons.format_underline,
                          isActive: _isFormatActive(Attribute.underline),
                          onPressed: () => _toggleFormat(Attribute.underline),
                          tooltip: 'Underline',
                        ),
                        // Strikethrough button
                        _buildFormatButton(
                          icon: Icons.format_strikethrough,
                          isActive: _isFormatActive(Attribute.strikeThrough),
                          onPressed: () => _toggleFormat(Attribute.strikeThrough),
                          tooltip: 'Strikethrough',
                        ),
                        const VerticalDivider(
                          width: 16,
                          thickness: 1,
                          indent: 8,
                          endIndent: 8,
                          color: Colors.grey,
                        ),
                        // Bullet list
                        _buildFormatButton(
                          icon: Icons.format_list_bulleted,
                          isActive: _isFormatActive(Attribute.ul),
                          onPressed: () => _toggleFormat(Attribute.ul),
                          tooltip: 'Bullet List',
                        ),
                        // Numbered list
                        _buildFormatButton(
                          icon: Icons.format_list_numbered,
                          isActive: _isFormatActive(Attribute.ol),
                          onPressed: () => _toggleFormat(Attribute.ol),
                          tooltip: 'Numbered List',
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  child: AbsorbPointer(
                    absorbing: _isSending,
                    child: QuillEditor.basic(
                      controller: _bodyController,
                      focusNode: _focusNode,
                      scrollController: ScrollController(),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              _isSending
                  ? const Center(child: CircularProgressIndicator(color: Colors.green))
                  : ElevatedButton.icon(
                onPressed: _sendNotification,
                icon: const Icon(Icons.send, color: Colors.white),
                label: const Text('Kirim Notifikasi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 30, vertical: 15),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormatButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isActive ? Colors.grey.shade300 : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              color: isActive ? Colors.green : Colors.black87,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}