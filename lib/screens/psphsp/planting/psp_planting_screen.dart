// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../services/google_sheets_api.dart';

class PspPlantingScreen extends StatefulWidget {
  final String spreadsheetId;
  final String region;

  const PspPlantingScreen({
    super.key,
    required this.spreadsheetId,
    required this.region,
  });

  @override
  State<PspPlantingScreen> createState() => _PspPlantingScreenState();
}

class _PspPlantingScreenState extends State<PspPlantingScreen> {
  final _formKey = GlobalKey<FormState>();
  late GoogleSheetsApi _googleSheetsApi;

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isGettingLocation = false;

  // --- Data untuk Dropdown ---
  List<Map<String, dynamic>> _availableFields = [];
  Map<String, dynamic>? _selectedFieldData;
  List<String> _fieldAssistantList = [];

  // --- Controllers ---
  final TextEditingController _hamletController = TextEditingController();
  final TextEditingController _villageController = TextEditingController();
  final TextEditingController _subDistrictController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _zoneController = TextEditingController();
  final TextEditingController _coordinateController = TextEditingController();
  final TextEditingController _plantingDateController = TextEditingController();

  // Teknis (Hanya untuk Vegetative)
  final TextEditingController _space1Controller = TextEditingController();
  final TextEditingController _plantingSpaceController = TextEditingController();
  final TextEditingController _space2Controller = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _seedLotController = TextEditingController();
  final TextEditingController _seedQtyController = TextEditingController();
  final TextEditingController _usageController = TextEditingController();

  // --- Dropdown Values ---
  final String _selectedStage = "Planting";

  String? _selectedZone; // <--- Tambahkan variabel ini
  final List<String> _zoneList = ["Zone 1", "Zone 2", "Zone 3", "Zone 4"]; // <--- List opsi

  String? _selectedFA;
  String? _selectedIsoYesNo;
  String? _selectedIsoType;
  String? _selectedIsoDist;
  String? _selectedPlantingMethod;

  // --- Colors ---
  final Color _primaryColor = Colors.teal.shade800;

  final TextEditingController _fieldDisplayController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _googleSheetsApi = GoogleSheetsApi(widget.spreadsheetId);
    _loadInitialData();
  }

  @override
  void dispose() {
    _hamletController.dispose();
    _villageController.dispose();
    _subDistrictController.dispose();
    _districtController.dispose();
    _zoneController.dispose();
    _coordinateController.dispose();
    _plantingDateController.dispose();
    _space1Controller.dispose();
    _plantingSpaceController.dispose();
    _space2Controller.dispose();
    _remarksController.dispose();
    _seedLotController.dispose();
    _seedQtyController.dispose();
    _usageController.dispose();
    _fieldDisplayController.dispose();
    super.dispose();
  }

  // --- FUNGSI GET LOCATION & ADDRESS ---
  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Location services are disabled. Please enable GPS.';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied.';
      }

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      _coordinateController.text = "${position.latitude}, ${position.longitude}";

      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
            position.latitude, position.longitude);

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          setState(() {
            _villageController.text = place.subLocality ?? "";
            _subDistrictController.text = place.locality ?? "";
            _districtController.text = place.subAdministrativeArea ?? "";
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location & Address updated!"), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        debugPrint("Error reverse geocoding: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Coordinates found, but failed to fetch address name.")),
        );
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isGettingLocation = false);
    }
  }

  Future<void> _loadInitialData() async {
    try {
      await _googleSheetsApi.init();
      final fields = await _googleSheetsApi.getAvailableFields('Vegetative');

      final docSnapshot = await FirebaseFirestore.instance
          .collection('regions')
          .doc('psp')
          .get();

      List<String> faList = [];
      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        if (data != null && data['zones'] != null) {
          final zonesMap = data['zones'] as Map<String, dynamic>;
          zonesMap.forEach((key, value) {
            if (value['field_assistant'] != null) {
              final faArray = List<String>.from(value['field_assistant']);
              faList.addAll(faArray);
            }
          });
        }
      }
      faList = faList.toSet().toList()..sort();

      if (mounted) {
        setState(() {
          _availableFields = fields;
          _fieldAssistantList = faList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error loading data: $e")));
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _plantingDateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _submitData() async {
    if (_selectedFieldData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a Field Number first!")),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      // 1. Ambil Target Baris
      final int targetRowIndex = _selectedFieldData!['rowIndex'];

      // 2. Siapkan Formula String
      // DAS = TODAY() - Kolom M (Planting Date)
      final String formulaDAS = "=TODAY()-M$targetRowIndex";
      final String formulaWeekPlanting = "=WEEKNUM(V$targetRowIndex)";
      final String formulaMonthPlanting = "=TEXT(M$targetRowIndex; \"MMMM\")";

      // 3A. Mapping untuk VEGETATIVE (LENGKAP: 13-37)
      Map<int, String> vegetativeUpdates = {
        13: _plantingDateController.text,
        14: _hamletController.text,
        15: _villageController.text,
        16: _subDistrictController.text,
        17: _districtController.text,
        18: _zoneController.text,
        19: _selectedFA ?? "-",
        20: _coordinateController.text,
        21: _selectedStage,
        22: _plantingDateController.text,
        23: formulaWeekPlanting,
        24: formulaDAS, // <--- RUMUS DAS (Auto Update)
        25: formulaWeekPlanting,
        26: formulaMonthPlanting,
        27: _selectedIsoYesNo ?? "-",
        28: _selectedIsoType ?? "-",
        29: _selectedIsoDist ?? "-",
        30: _space1Controller.text,
        31: _plantingSpaceController.text,
        32: _space2Controller.text,
        33: _remarksController.text,
        34: _selectedPlantingMethod ?? "-",
        35: _seedLotController.text,
        36: _seedQtyController.text,
        37: "${_usageController.text}%",
      };

      // 3B. Mapping untuk GENERATIVE (HANYA DATA POKOK: 13-26)
      Map<int, String> generativeUpdates = {
        13: _plantingDateController.text,
        14: _hamletController.text,
        15: _villageController.text,
        16: _subDistrictController.text,
        17: _districtController.text,
        18: _zoneController.text,
        19: _selectedFA ?? "-",
        20: _coordinateController.text,
        21: _selectedStage,
        22: _plantingDateController.text,
        23: formulaWeekPlanting,
        24: formulaDAS, // <--- RUMUS DAS (Auto Update)
        25: formulaWeekPlanting,
        26: formulaMonthPlanting,
      };

      // 4. Eksekusi Double Update
      await Future.wait([
        _googleSheetsApi.updateSpecificCells('Vegetative', targetRowIndex, vegetativeUpdates),
        _googleSheetsApi.updateSpecificCells('Generative', targetRowIndex, generativeUpdates),
      ]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
                children: [
                  Icon(Icons.cloud_done_rounded, color: Colors.white),
                  SizedBox(width: 10),
                  Expanded(child: Text("Data saved! Full details to Vegetative, Basic info to Generative."))
                ]
            ),
            backgroundColor: Colors.teal,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to save: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // --- FUNGSI SEARCHABLE DROPDOWN (DIALOG) ---
  void _showFieldSearchDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String searchQuery = "";

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            // Filter list berdasarkan query pencarian
            final filteredList = _availableFields.where((field) {
              final fieldInfo = "${field['fieldNumber']} - ${field['farmer']}".toLowerCase();
              return fieldInfo.contains(searchQuery.toLowerCase());
            }).toList();

            return AlertDialog(
              title: const Text("Select Field"),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Input Pencarian
                    TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: "Search Field No or Farmer...",
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onChanged: (val) {
                        setStateDialog(() {
                          searchQuery = val;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    // Daftar Hasil
                    Expanded(
                      child: filteredList.isEmpty
                          ? const Center(child: Text("No field found."))
                          : ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredList.length,
                        itemBuilder: (context, index) {
                          final item = filteredList[index];
                          final displayText = "${item['fieldNumber']} - ${item['farmer']}";
                          return ListTile(
                            title: Text(displayText, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text("Row Index: ${item['rowIndex']}"),
                            onTap: () {
                              // Set data yang dipilih
                              setState(() {
                                _selectedFieldData = item;
                                _fieldDisplayController.text = displayText; // Tampilkan di textfield utama
                              });
                              Navigator.pop(context); // Tutup dialog
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Close"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Planting Phase", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
        ),
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: _primaryColor.withOpacity(0.6)),
          ),
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_primaryColor.withOpacity(0.1), Colors.white],
              ),
            ),
          ),

          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 100, 20, 100),
              physics: const BouncingScrollPhysics(),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- SECTION 1: FIELD SELECTION ---
                    _buildSectionHeader("Select Field", Icons.search_rounded),
                    const SizedBox(height: 10),
                    _buildGlassContainer(
                      children: [
                        // GANTI WIDGET DROPDOWN LAMA DENGAN INI:
                        GestureDetector(
                          onTap: _showFieldSearchDialog, // Panggil dialog saat diklik
                          child: AbsorbPointer( // Mencegah keyboard muncul di layar utama
                            child: TextFormField(
                              controller: _fieldDisplayController,
                              readOnly: true, // Pastikan read only
                              decoration: InputDecoration(
                                labelText: "Search Field Number / Farmer",
                                prefixIcon: Icon(Icons.qr_code_scanner, color: _primaryColor),
                                suffixIcon: const Icon(Icons.arrow_drop_down),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              validator: (value) {
                                if (_selectedFieldData == null) {
                                  return "Please select a field";
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (_selectedFieldData != null) ...[
                      const SizedBox(height: 24),

                      // --- SECTION 2: LOCATION & STAFF ---
                      _buildSectionHeader("Location & Staff", Icons.location_on_rounded),
                      const SizedBox(height: 10),
                      _buildGlassContainer(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center, // Sejajarkan vertikal
                            children: [
                              // 1. Kolom Input (Hanya menampilkan teks)
                              Expanded(
                                child: _buildTextField(
                                  _coordinateController,
                                  "Coordinate",
                                  Icons.my_location,
                                  keyboardType: TextInputType.text,
                                  // Tidak ada suffixIcon lagi di sini
                                ),
                              ),

                              const SizedBox(width: 8), // Jarak antara input dan tombol

                              // 2. Tombol GET (Pin Map)
                              SizedBox(
                                height: 48, // Tinggi disesuaikan agar mirip dengan tinggi TextField
                                child: ElevatedButton.icon(
                                  onPressed: _isGettingLocation ? null : _getCurrentLocation,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _primaryColor, // Warna hijau teal sesuai tema
                                    foregroundColor: Colors.white, // Warna teks/icon putih
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    elevation: 2,
                                  ),
                                  // Logika Tampilan: Loading Spinner atau Icon Pin
                                  icon: _isGettingLocation
                                      ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                      : const Icon(Icons.location_pin, size: 20), // Icon Pin Map
                                  label: Text(
                                    _isGettingLocation ? "..." : "GET",
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          Row(
                            children: [
                              Expanded(child: _buildTextField(_hamletController, "Hamlet (Dusun)", Icons.home_work_outlined)),
                              const SizedBox(width: 10),
                              Expanded(child: _buildTextField(_villageController, "Village (Desa)", Icons.holiday_village_outlined)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(child: _buildTextField(_subDistrictController, "Sub-District", Icons.map_outlined)),
                              const SizedBox(width: 10),
                              Expanded(child: _buildTextField(_districtController, "District", Icons.map_rounded)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50, // Latar belakang oranye muda
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline_rounded, size: 20, color: Colors.orange.shade800),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Village, Sub-district, District is Automatically filled by GET Coordinate. Check Again!",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange.shade900,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildDropdownSimple(
                            "Zone / Area",
                            _zoneList, // List: Zone 1, Zone 2, dst
                                (val) {
                              setState(() {
                                _selectedZone = val;
                                // PENTING: Kita update controller juga agar tombol SIMPAN tetap jalan tanpa ubah kode lain
                                _zoneController.text = val ?? "";
                              });
                            },
                            value: _selectedZone,
                            icon: Icons.share_location_rounded,
                          ),
                          const SizedBox(height: 10),

                          _buildDropdownSimple(
                              "Field Assistant",
                              _fieldAssistantList,
                                  (v) => setState(() => _selectedFA = v),
                              value: _selectedFA,
                              icon: Icons.person_outline
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // --- SECTION 3: PLANTING DETAILS ---
                      _buildSectionHeader("Planting Info", Icons.calendar_today_rounded),
                      const SizedBox(height: 10),
                      _buildGlassContainer(
                        children: [
                          GestureDetector(
                            onTap: () => _selectDate(context),
                            child: AbsorbPointer(
                              child: _buildTextField(
                                  _plantingDateController,
                                  "Planting Date",
                                  Icons.date_range,
                                  validator: (v) => v!.isEmpty ? "Required" : null
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              children: [
                                Icon(Icons.auto_awesome, size: 16, color: Colors.orange.shade700),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    "Week, Month & DAS will be calculated automatically in Database.",
                                    style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.black54),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // --- SECTION 4: ISOLATION ---
                      _buildSectionHeader("Isolation", Icons.security_rounded),
                      const SizedBox(height: 10),
                      _buildGlassContainer(
                        children: [
                          _buildDropdownSimple("Isolation Compliance", ["A= Yes", "B= No"], (v) => _selectedIsoYesNo = v),
                          const SizedBox(height: 10),
                          _buildDropdownSimple("Isolation Type", ["A= Other seed production", "B= Commercial"], (v) => _selectedIsoType = v),
                          const SizedBox(height: 10),
                          _buildDropdownSimple("Isolation Distance", ["A= >400", "B= <400"], (v) => _selectedIsoDist = v),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // --- SECTION 5: TECHNICAL & SEED ---
                      _buildSectionHeader("Seed & Technical", Icons.science_rounded),
                      const SizedBox(height: 10),
                      _buildGlassContainer(
                        children: [
                          _buildDropdownSimple(
                              "Planting Method",
                              [
                                "A = Normal - One seed per hole",
                                "B = Normal - Two seed per hole",
                                "C = Pair to Pair - One Seed per hole",
                                "D = Pair to Pair - Two Seed per hole"
                              ],
                                  (v) => _selectedPlantingMethod = v,
                              isDense: true
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(child: _buildTextField(_space1Controller, "Space 1", Icons.space_bar, keyboardType: TextInputType.number)),
                              const SizedBox(width: 10),
                              Expanded(child: _buildTextField(_plantingSpaceController, "P. Space", Icons.linear_scale, keyboardType: TextInputType.number)),
                              const SizedBox(width: 10),
                              Expanded(child: _buildTextField(_space2Controller, "Space 2", Icons.space_bar, keyboardType: TextInputType.number)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildTextField(_seedLotController, "Seed Lot #", Icons.qr_code),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(child: _buildTextField(_seedQtyController, "Seed Qty (kg)", Icons.scale, keyboardType: TextInputType.number)),
                              const SizedBox(width: 10),
                              Expanded(child: _buildTextField(
                                  _usageController,
                                  "PS Usage",
                                  Icons.percent,
                                  keyboardType: TextInputType.number,
                                  suffixText: "%"
                              )),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildTextField(_remarksController, "Planting Remarks", Icons.comment, maxLines: 2),
                        ],
                      ),

                      const SizedBox(height: 40),

                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 5,
                            shadowColor: _primaryColor.withOpacity(0.5),
                          ),
                          child: _isSubmitting
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text("UPDATE PLANTING DATA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: _primaryColor, size: 20),
        const SizedBox(width: 8),
        Text(title.toUpperCase(), style: TextStyle(color: _primaryColor, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.8)),
      ],
    );
  }

  Widget _buildGlassContainer({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {TextInputType keyboardType = TextInputType.text, int maxLines = 1, String? Function(String?)? validator, String? suffixText, Widget? suffixIcon}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffixText,
        suffixIcon: suffixIcon,
        prefixIcon: Icon(icon, color: Colors.grey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
    );
  }

  Widget _buildDropdownSimple(String label, List<String> items, Function(String?) onChanged, {bool isDense = false, String? value, IconData? icon}) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(fontSize: isDense ? 12 : 14)))).toList(),
      onChanged: onChanged,
    );
  }
}