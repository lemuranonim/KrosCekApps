import 'package:flutter/material.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class AccountManagement extends StatefulWidget {
  const AccountManagement({super.key});

  @override
  State<AccountManagement> createState() => _AccountManagementState();
}

class _AccountManagementState extends State<AccountManagement> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _selectedRoleType;
  List<String> _adminEmails = [];

  // Map role types to their display names
  final Map<String, String> _roleTypes = {
    'adminEmails': 'Admin Role',
    'pspEmails': 'PSP Role',
    'userEmails': 'QA Role',
    'swcEmails': 'HSP Role',
  };

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return PopScope(
      // Callback saat pengguna menekan tombol back
      canPop: false, // Mencegah pop langsung
      // ignore: deprecated_member_use
      onPopInvoked: (didPop) {
        // didPop akan false karena canPop: false
        context.go('/admin');
        return;
      },
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.go('/admin'),
          ),
          title: const Text('Account Roles',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.green,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            if (_selectedRoleType != null)
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white),
                onPressed: _showAddEmailDialog,
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.green))
            : _buildMainContent(),
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        // Role Type Selection
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildRoleTypeDropdown(),
        ),

        // Emails List
        if (_selectedRoleType != null) _buildEmailsList(),
      ],
    );
  }

  Widget _buildRoleTypeDropdown() {
    final displayText = _selectedRoleType != null
        ? _roleTypes[_selectedRoleType]!
        : 'Pilih Role Type';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.green.shade50],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withAlpha(51),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.green.withAlpha(102),
          style: BorderStyle.solid,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: DropdownButtonHideUnderline(
          child: DropdownButton2<String>(
            value: _selectedRoleType,
            hint: Text(
              'Pilih Role Type',
              style: TextStyle(
                color: Colors.green.shade800.withAlpha((0.6 * 255).round()),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            isExpanded: true,
            customButton: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      displayText,
                      style: TextStyle(
                        color: _selectedRoleType == null
                            ? Colors.green.shade800.withAlpha((0.6 * 255).round())
                            : Colors.green.shade800,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade600,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.expand_more, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
            dropdownStyleData: DropdownStyleData(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withAlpha(51),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              maxHeight: MediaQuery.of(context).size.height * 0.4,
              width: MediaQuery.of(context).size.width * 0.8,
              padding: const EdgeInsets.symmetric(vertical: 6),
              offset: const Offset(0, -10),
            ),
            menuItemStyleData: const MenuItemStyleData(
              height: 48,
              padding: EdgeInsets.symmetric(horizontal: 16),
            ),
            style: TextStyle(
              color: Colors.green.shade900,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            items: _roleTypes.entries.map((entry) {
              final roleKey = entry.key;
              final displayName = entry.value;
              return DropdownMenuItem<String>(
                value: roleKey,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: _selectedRoleType == roleKey
                        ? Colors.green.shade50
                        : Colors.transparent,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getRoleIcon(roleKey),
                        color: Colors.green.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        displayName,
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontSize: 15,
                          fontWeight: _selectedRoleType == roleKey
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                _loadRoleData(value);
              }
            },
          ),
        ),
      ),
    );
  }

  IconData _getRoleIcon(String roleKey) {
    switch (roleKey) {
      case 'adminEmails':
        return Icons.admin_panel_settings_outlined;
      case 'pspEmails':
        return Icons.verified_user_outlined;
      case 'userEmails':
        return Icons.person_outline;
      case 'swcEmails':
        return Icons.security_outlined;
      default:
        return Icons.group_outlined;
    }
  }

  Widget _buildEmailsList() {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withAlpha(51),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: Colors.green.withAlpha(102),
            style: BorderStyle.solid,
            width: 1.5,
          ),
        ),
        child: ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: _adminEmails.length,
          itemBuilder: (context, index) {
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withAlpha(51),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  _adminEmails[index],
                  style: TextStyle(
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: IconButton(
                  icon: Icon(Icons.delete, color: Colors.red[800]),
                  onPressed: () => _confirmDeleteEmail(_adminEmails[index]),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _loadRoleData(String roleType) async {
    setState(() => _isLoading = true);
    try {
      final doc = await _firestore.collection('roles').doc(roleType).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _selectedRoleType = roleType;
          _adminEmails = List<String>.from(data['emails'] ?? []);
        });
      } else {
        setState(() {
          _selectedRoleType = roleType;
          _adminEmails = [];
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat data: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showAddEmailDialog() {
    _emailController.clear();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Tambah Email Baru',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: _emailController,
            decoration: const InputDecoration(hintText: 'Alamat Email'),
            keyboardType: TextInputType.emailAddress,
          ),
          actions: [
            ElevatedButton(
              onPressed: () => context.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                context.pop(context);
                await _addEmail();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await _firestore.collection('roles').doc(_selectedRoleType).set({
        'emails': FieldValue.arrayUnion([email])
      }, SetOptions(merge: true));

      await _loadRoleData(_selectedRoleType!);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menambahkan email: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _confirmDeleteEmail(String email) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Hapus Email?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: RichText(
            text: TextSpan(
              children: [
                const TextSpan(text: 'Anda yakin ingin menghapus ',
                  style: TextStyle(color: Colors.black),
                ),
                TextSpan(
                  text: email,
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                ),
                const TextSpan(text: '?',
                  style: TextStyle(color: Colors.black),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => context.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                context.pop(context);
                await _deleteEmail(email);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteEmail(String email) async {
    setState(() => _isLoading = true);
    try {
      await _firestore.collection('roles').doc(_selectedRoleType).update({
        'emails': FieldValue.arrayRemove([email])
      });

      await _loadRoleData(_selectedRoleType!);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus email: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}