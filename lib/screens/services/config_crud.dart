import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class CrudPage extends StatefulWidget {
  const CrudPage({super.key});

  @override
  CrudPageState createState() => CrudPageState();
}

class CrudPageState extends State<CrudPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _regionController = TextEditingController();
  final TextEditingController _spreadsheetIdController = TextEditingController();
  String? _selectedRegionName;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      // ignore: deprecated_member_use
      onPopInvoked: (didPop) {
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
          title: const Text(
            'Config Regions',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.green))
            : _buildMainContent(),
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.green,
          onPressed: _showAddRegionDialog,
          tooltip: 'Tambah Region',
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('config').doc('regions').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        Map<String, dynamic>? data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null || data.isEmpty) {
          return const Center(child: Text('No regions data available'));
        }

        // Convert map to list of entries for ListView
        List<MapEntry<String, dynamic>> regions = data.entries.toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: regions.length,
          itemBuilder: (context, index) {
            final regionName = regions[index].key;
            final spreadsheetId = regions[index].value.toString();
            return _buildRegionCard(regionName, spreadsheetId);
          },
        );
      },
    );
  }

  Widget _buildRegionCard(String regionName, String spreadsheetId) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        title: Text(
          regionName,
          style: const TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(spreadsheetId),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () {
                _regionController.text = regionName;
                _spreadsheetIdController.text = spreadsheetId;
                _selectedRegionName = regionName;
                _showAddRegionDialog();
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _confirmDeleteRegion(regionName),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddRegionDialog() {
    if (_selectedRegionName == null) {
      _regionController.clear();
      _spreadsheetIdController.clear();
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            _selectedRegionName == null ? 'Tambah Region' : 'Edit Region',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _regionController,
                decoration: const InputDecoration(hintText: 'Nama Region'),
              ),
              TextField(
                controller: _spreadsheetIdController,
                decoration: const InputDecoration(hintText: 'Spreadsheet ID'),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => context.pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                context.pop();
                await _addOrUpdateRegion();
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

  Future<void> _addOrUpdateRegion() async {
    if (_regionController.text.isNotEmpty && _spreadsheetIdController.text.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        Map<String, dynamic> updates = {};

        // If editing, remove old field first
        if (_selectedRegionName != null && _selectedRegionName != _regionController.text) {
          await _firestore.collection('config').doc('regions').update({
            _selectedRegionName!: FieldValue.delete(),
          });
        }

        // Add or update the field
        updates[_regionController.text] = _spreadsheetIdController.text;

        await _firestore.collection('config').doc('regions').set(
            updates,
            SetOptions(merge: true)
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Data region berhasil disimpan')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan data: $e')),
        );
      } finally {
        _clearFields();
        setState(() => _isLoading = false);
      }
    }
  }

  void _clearFields() {
    _regionController.clear();
    _spreadsheetIdController.clear();
    _selectedRegionName = null;
  }

  void _confirmDeleteRegion(String regionName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hapus Region?'),
          content: Text('Apakah Anda yakin ingin menghapus region $regionName?'),
          actions: [
            ElevatedButton(
              onPressed: () => context.pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                context.pop();
                await _deleteRegion(regionName);
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

  Future<void> _deleteRegion(String regionName) async {
    setState(() => _isLoading = true);
    try {
      await _firestore.collection('config').doc('regions').update({
        regionName: FieldValue.delete(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Region $regionName berhasil dihapus')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus region: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}