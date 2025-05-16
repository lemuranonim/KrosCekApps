import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

class FilterRegionsScreen extends StatefulWidget {
  final Function(List<String>)? onRegionsSelected;

  const FilterRegionsScreen({
    super.key,
    this.onRegionsSelected,
  });

  @override
  State<FilterRegionsScreen> createState() => _FilterRegionsScreenState();
}

class _FilterRegionsScreenState extends State<FilterRegionsScreen> {
  bool _isLoading = true;
  List<String> _availableRegions = [];
  Set<String> _selectedRegions = {};
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _regionNameController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _regionNameController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load from Firestore
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('config')
          .doc('filter')
          .get();

      if (snapshot.exists) {
        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        if (data.containsKey('hsp')) {
          List<String> regions = List<String>.from(data['hsp']);
          setState(() {
            _availableRegions = regions;
          });
        }
      }

      // Load saved preferences
      await _loadSavedSelections();

    } catch (e) {
      debugPrint('Error loading regions: $e');
      _showErrorSnackbar('Failed to load regions. Please try again.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSavedSelections() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String>? savedRegions = prefs.getStringList('selectedRegions');

      if (savedRegions != null && savedRegions.isNotEmpty) {
        setState(() {
          _selectedRegions = Set.from(savedRegions);
        });
      }
    } catch (e) {
      debugPrint('Error loading saved selections: $e');
    }
  }

  Future<void> _saveSelections() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('selectedRegions', _selectedRegions.toList());

      if (widget.onRegionsSelected != null) {
        widget.onRegionsSelected!(_selectedRegions.toList());
      }
    } catch (e) {
      debugPrint('Error saving selections: $e');
      _showErrorSnackbar('Failed to save selections.');
    }
  }

  Future<void> _addRegion(String regionName) async {
    if (regionName.trim().isEmpty) {
      _showErrorSnackbar('Region name cannot be empty.');
      return;
    }

    if (_availableRegions.contains(regionName.trim())) {
      _showErrorSnackbar('Region already exists.');
      return;
    }

    try {
      List<String> updatedRegions = List.from(_availableRegions);
      updatedRegions.add(regionName.trim());

      await FirebaseFirestore.instance
          .collection('config')
          .doc('filter')
          .update({'hsp': updatedRegions});

      setState(() {
        _availableRegions = updatedRegions;
      });

      _showSuccessSnackbar('Region added successfully.');
    } catch (e) {
      debugPrint('Error adding region: $e');
      _showErrorSnackbar('Failed to add region. Please try again.');
    }
  }

  Future<void> _updateRegion(String oldName, String newName) async {
    if (newName.trim().isEmpty) {
      _showErrorSnackbar('Region name cannot be empty.');
      return;
    }

    if (oldName == newName.trim()) {
      return; // No changes needed
    }

    if (_availableRegions.contains(newName.trim())) {
      _showErrorSnackbar('Region name already exists.');
      return;
    }

    try {
      List<String> updatedRegions = List.from(_availableRegions);
      int index = updatedRegions.indexOf(oldName);
      if (index != -1) {
        updatedRegions[index] = newName.trim();
      }

      await FirebaseFirestore.instance
          .collection('config')
          .doc('filter')
          .update({'hsp': updatedRegions});

      // Update selected regions if the edited region was selected
      if (_selectedRegions.contains(oldName)) {
        _selectedRegions.remove(oldName);
        _selectedRegions.add(newName.trim());
        await _saveSelections();
      }

      setState(() {
        _availableRegions = updatedRegions;
      });

      _showSuccessSnackbar('Region updated successfully.');
    } catch (e) {
      debugPrint('Error updating region: $e');
      _showErrorSnackbar('Failed to update region. Please try again.');
    }
  }

  Future<void> _deleteRegion(String regionName) async {
    try {
      List<String> updatedRegions = List.from(_availableRegions);
      updatedRegions.remove(regionName);

      await FirebaseFirestore.instance
          .collection('config')
          .doc('filter')
          .update({'hsp': updatedRegions});

      // Remove from selected regions if selected
      if (_selectedRegions.contains(regionName)) {
        _selectedRegions.remove(regionName);
        await _saveSelections();
      }

      setState(() {
        _availableRegions = updatedRegions;
      });

      _showSuccessSnackbar('Region deleted successfully.');
    } catch (e) {
      debugPrint('Error deleting region: $e');
      _showErrorSnackbar('Failed to delete region. Please try again.');
    }
  }

  void _showAddRegionDialog() {
    _regionNameController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Add New Region',
          style: TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: _regionNameController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter region name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.red),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _addRegion(_regionNameController.text);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditRegionDialog(String regionName) {
    _regionNameController.text = regionName;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Edit Region',
          style: TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: _regionNameController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter new region name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.red),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateRegion(regionName, _regionNameController.text);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showDeleteRegionDialog(String regionName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Region'),
        content: Text('Are you sure you want to delete "$regionName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteRegion(regionName);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _toggleRegion(String region) {
    setState(() {
      if (_selectedRegions.contains(region)) {
        _selectedRegions.remove(region);
      } else {
        _selectedRegions.add(region);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedRegions = Set.from(_availableRegions);
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedRegions.clear();
    });
  }

  List<String> _getFilteredRegions() {
    if (_searchQuery.isEmpty) {
      return _availableRegions;
    }
    return _availableRegions
        .where((region) => region.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.go('/admin'),
          ),
          title: const Text(
            'Filter Regions',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.green.shade800, Colors.green.shade600],
              ),
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.check_circle_outline),
              tooltip: 'Select All',
              onPressed: _selectAll,
            ),
            IconButton(
              icon: const Icon(Icons.cancel_outlined),
              tooltip: 'Deselect All',
              onPressed: _deselectAll,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.green))
            : Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search regions...',
                  prefixIcon: const Icon(Icons.search, color: Colors.green),
                  fillColor: Colors.white,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.green.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.green, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),

            // Selection counts
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0 ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Available Regions: ${_availableRegions.length}',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'Selected: ${_selectedRegions.length}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 24),

            // Regions list
            Expanded(
              child: _buildRegionsList(),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.green,
          onPressed: _showAddRegionDialog,
          child: const Icon(Icons.add),
        ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget _buildRegionsList() {
    List<String> filteredRegions = _getFilteredRegions();

    if (filteredRegions.isEmpty) {
      return Center(
        child: Text(
          _searchQuery.isEmpty
              ? 'No regions available'
              : 'No regions matching "$_searchQuery"',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: filteredRegions.length,
      itemBuilder: (context, index) {
        String region = filteredRegions[index];
        bool isSelected = _selectedRegions.contains(region);

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected ? Colors.green : Colors.transparent,
              width: isSelected ? 2 : 0,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            title: Text(
              region,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.green : Colors.black87,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showEditRegionDialog(region),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _showDeleteRegionDialog(region),
                ),
                Checkbox(
                  value: isSelected,
                  onChanged: (bool? value) {
                    _toggleRegion(region);
                  },
                  activeColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
            onTap: () {
              _toggleRegion(region);
            },
          ),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.cancel, color: Colors.white),
              label: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () async {
                await _saveSelections();
                if (mounted) {
                  Navigator.pop(context, _selectedRegions.toList());
                }
              },
              icon: const Icon(Icons.check_circle, color: Colors.white),
              label: const Text(
                'Apply Filters',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
