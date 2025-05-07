import 'package:flutter/material.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import '../models/region_model.dart';
import '../services/region_data_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegionsDashboard extends StatefulWidget {
  const RegionsDashboard({super.key});

  @override
  State<RegionsDashboard> createState() => _RegionsDashboardState();
}

class _RegionsDashboardState extends State<RegionsDashboard> {
  final RegionDataService _dataService = RegionDataService();
  final _districtController = TextEditingController();
  final _qaSpvNameController = TextEditingController();

  Region? _selectedRegion;
  String? _selectedQaSpvName;
  bool _isLoading = false;

  @override
  void dispose() {
    _districtController.dispose();
    _qaSpvNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Regions Dashboard',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_selectedRegion != null)
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              onPressed: _showAddQaSpvDialog,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : _buildMainContent(),
      floatingActionButton: _selectedQaSpvName != null
          ? FloatingActionButton(
        backgroundColor: Colors.green,
        onPressed: _showAddDistrictDialog,
        child: const Icon(Icons.add, color: Colors.white),
      )
          : null,
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        // Region Selection
        FutureBuilder<List<String>>(
          future: _dataService.fetchAllRegionNames(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: Colors.green));
            }
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildRegionDropdown(snapshot.data!),
            );
          },
        ),

        // QA SPV Selection
        if (_selectedRegion != null) _buildQaSpvSection(),

        // Districts List
        if (_selectedQaSpvName != null) _buildDistrictsList(),
      ],
    );
  }

  Widget _buildRegionDropdown(List<String> regionNames) {
    final displayText = _selectedRegion?.id ?? 'Pilih Region';

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
            value: _selectedRegion?.id,
            hint: Text(
              'Pilih Region',
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
                        color: _selectedRegion == null
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
            items: regionNames.map((String region) {
              return DropdownMenuItem<String>(
                value: region,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: _selectedRegion?.id == region
                        ? Colors.green.shade50
                        : Colors.transparent,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          color: Colors.green.shade700, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        region,
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontSize: 15,
                          fontWeight: _selectedRegion?.id == region
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
                _loadRegionData(value);
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildQaSpvSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
      child: Container(
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
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton2<String>(
                    value: _selectedQaSpvName,
                    hint: Text(
                      'Pilih QA SPV',
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
                              _selectedQaSpvName ?? 'Pilih QA SPV',
                              style: TextStyle(
                                color: _selectedQaSpvName == null
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
                    items: _selectedRegion!.qaSupervisors.keys.map((name) {
                      return DropdownMenuItem<String>(
                        value: name,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: _selectedQaSpvName == name
                                ? Colors.green.shade50
                                : Colors.transparent,
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.person_outline,
                                  color: Colors.green.shade700, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                name,
                                style: TextStyle(
                                  color: Colors.green.shade800,
                                  fontSize: 15,
                                  fontWeight: _selectedQaSpvName == name
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (name) => setState(() => _selectedQaSpvName = name),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  icon: Icon(Icons.delete, color: Colors.red[800]),
                  onPressed: _selectedQaSpvName != null ? _confirmDeleteQaSpv : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDistrictsList() {
    final districts = _selectedRegion!.qaSupervisors[_selectedQaSpvName]!.districts;

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
          itemCount: districts.length,
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
                  districts[index],
                  style: TextStyle(
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: IconButton(
                  icon: Icon(Icons.delete, color: Colors.red[800]),
                  onPressed: () => _confirmDeleteDistrict(districts[index]),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // CRUD Operations (keep the same as before)
  Future<void> _loadRegionData(String regionId) async {
    setState(() => _isLoading = true);
    try {
      final region = await _dataService.fetchRegionData(regionId);
      if (mounted) {
        setState(() {
          _selectedRegion = region;
          if (_selectedQaSpvName != null &&
              !region.qaSupervisors.containsKey(_selectedQaSpvName)) {
            _selectedQaSpvName = null;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat data: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  void _showAddQaSpvDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Nambah QA SPV Anyar',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: _qaSpvNameController,
            decoration: const InputDecoration(hintText: 'Jeneng QA SPV'),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Ora sido'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _addQaSpv();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Simpen'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addQaSpv() async {
    final qaSpvName = _qaSpvNameController.text.trim();
    if (qaSpvName.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('regions')
          .doc(_selectedRegion!.id)
          .update({
        'qa_spv.$qaSpvName': {
          'districts': [],
        }
      });

      await _loadRegionData(_selectedRegion!.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menambahkan QA SPV: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _confirmDeleteQaSpv() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Mbusek QA SPV?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: RichText(
            text: TextSpan(
              children: [
                const TextSpan(text: 'Njenengan saestu bade mbusek ',
                  style: TextStyle(color: Colors.black),
                ),
                TextSpan(
                  text: _selectedRegion!.qaSupervisors[_selectedQaSpvName]!.name,
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
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Ora sido'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _deleteQaSpv();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Busek'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteQaSpv() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('regions')
          .doc(_selectedRegion!.id)
          .update({
        'qa_spv.$_selectedQaSpvName': FieldValue.delete(),
      });

      setState(() => _selectedQaSpvName = null);
      await _loadRegionData(_selectedRegion!.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus QA SPV: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showAddDistrictDialog() {
    _districtController.clear();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Nambah District Anyar',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: _districtController,
            decoration: const InputDecoration(hintText: 'Jeneng District'),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, // Mengatur warna latar belakang tombol
                foregroundColor: Colors.white, // Mengatur warna teks tombol
              ),
              child: const Text('Ora sido'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _addDistrict();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, // Mengatur warna latar belakang tombol
                foregroundColor: Colors.white, // Mengatur warna teks tombol
              ),
              child: const Text('Simpen'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addDistrict() async {
    final districtName = _districtController.text.trim();
    if (districtName.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('regions')
          .doc(_selectedRegion!.id)
          .update({
        'qa_spv.$_selectedQaSpvName.districts': FieldValue.arrayUnion([districtName])
      });

      await _loadRegionData(_selectedRegion!.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menambahkan district: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _confirmDeleteDistrict(String districtName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Mbusek District?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: RichText(
            text: TextSpan(
              children: [
                const TextSpan(text: 'Njenengan saestu bade mbusek ',
                  style: TextStyle(color: Colors.black),
                ),
                TextSpan(
                  text: districtName,
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
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Ora sido'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _deleteDistrict(districtName);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Busek'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteDistrict(String districtName) async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('regions')
          .doc(_selectedRegion!.id)
          .update({
        'qa_spv.$_selectedQaSpvName.districts': FieldValue.arrayRemove([districtName])
      });

      await _loadRegionData(_selectedRegion!.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus district: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}