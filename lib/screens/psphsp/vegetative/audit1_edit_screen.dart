import 'dart:async'; // Untuk menggunakan Timer

import 'package:flutter/material.dart';
import 'package:gsheets/gsheets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import SharedPreferences untuk userName

import '../../services/config_manager.dart';
import '../../services/google_sheets_api.dart';

class Audit1EditScreen extends StatefulWidget {
  final List<String> row;
  final String region;
  final Function(List<String>) onSave; // Callback untuk mengirim data yang diperbarui

  const Audit1EditScreen({
    super.key,
    required this.row,
    required this.region,
    required this.onSave,
  });

  @override
  Audit1EditScreenState createState() => Audit1EditScreenState();
}

class Audit1EditScreenState extends State<Audit1EditScreen> {
  late List<String> row;
  late GoogleSheetsApi gSheetsApi;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _dateAuditController;
  late TextEditingController _revTglTanamController;

  String userEmail = 'Fetching...'; // Variabel untuk email pengguna
  String userName = 'Fetching...'; // Variabel untuk menyimpan nama pengguna
  late String spreadsheetId;

  String? selectedFI; // FI yang dipilih
  List<String> fiList = []; // Daftar FI untuk dropdown

  String? selectedPreviousCropActual;
  String? selectedIsolationAudit1;
  String? selectedIsolationType;
  String? selectedIsolationDistance;
  String? selectedCropHealth;
  String? selectedCropUniformity;

  final List<String> previousCropActualItems = ['A', 'B', 'C'];
  final List<String> isolationAudit1Items = ['Y', 'N'];
  final List<String> isolationTypeItems = ['A', 'B'];
  final List<String> isolationDistanceItems = ['A', 'B'];
  final List<String> cropHealthItems = ['1', '2', '3', '4', '5'];
  final List<String> cropUniformityItems = ['1', '2', '3', '4', '5'];

  bool isLoading = false;

  bool get isDiscardMode {
    // Recommendation dari Audit 4 disimpan di indeks 73
    if (widget.row.length > 73) {
      return widget.row[73] == 'Discard';
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _loadUserCredentials();
    row = List<String>.from(widget.row);

    _initHive();
    _fetchSpreadsheetId();

    _dateAuditController = TextEditingController(text: _convertToDateIfNecessary(row[30]));
    _revTglTanamController = TextEditingController(text: _convertToDateIfNecessary(row[32]));

    _loadFIList(widget.region);

    gSheetsApi = GoogleSheetsApi(spreadsheetId);
    gSheetsApi.init();

    // Initialize dropdown fields
    selectedPreviousCropActual = row[34].isNotEmpty ? row[34] : null;
    selectedIsolationAudit1 = row[35].isNotEmpty ? row[35] : null;
    selectedIsolationType = row[36].isNotEmpty ? row[36] : null;
    selectedIsolationDistance = row[37].isNotEmpty ? row[37] : null;
    selectedCropHealth = row[40].isNotEmpty ? row[40] : null;
    selectedCropUniformity = row[41].isNotEmpty ? row[41] : null;
  }

  Future<void> _fetchSpreadsheetId() async {
    spreadsheetId = ConfigManager.getSpreadsheetId(widget.region) ?? 'defaultSpreadsheetId';
  }

  Future<void> _loadFIList(String region) async {
    setState(() {
      isLoading = true; // Tampilkan loading
    });

    try {
      final gSheetsApi = GoogleSheetsApi('1cMW79EwaOa-Xqe_7xf89_VPiak1uvp_f54GHfNR7WyA');
      await gSheetsApi.init(); // Inisialisasi API
      final List<String> fetchedFI = await gSheetsApi.fetchFIByRegion('FI', region);

      setState(() {
        fiList = fetchedFI; // Perbarui daftar FI
        selectedFI = row[31].isNotEmpty ? row[31] : null; // Tetapkan nilai awal, null jika kosong
      });
    } catch (e) {
      debugPrint('Gagal mengambil data FI: $e');
    } finally {
      setState(() {
        isLoading = false; // Sembunyikan loading
      });
    }
  }

  void _initHive() async {
    await Hive.initFlutter();
    await Hive.openBox('pspVegetativeData'); // Buat box Hive untuk menyimpan data vegetative
  }

  Future<void> _saveToHive(List<String> rowData) async {
    var box = await Hive.openBox('pspVegetativeData');
    final cacheKey = 'detailScreenData_${rowData[2]}'; // Menggunakan fieldNumber atau ID unik lainnya sebagai kunci
    await box.put(cacheKey, rowData); // Simpan hanya rowData ke Hive
  }

  Future<void> _loadUserCredentials() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userEmail = prefs.getString('userEmail') ?? 'Unknown Email';
      userName = prefs.getString('userName') ?? 'Pengguna';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
            'Edit Audit 1',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            )
        ),
        backgroundColor: Colors.orange.shade700,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.orange.shade700, Colors.orange.shade100],
            stops: const [0.0, 0.3],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isLoading)
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      child: const LinearProgressIndicator(
                        backgroundColor: Colors.white,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                      ),
                    ),

                  // Main Card Container
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          // Field Information Section
                          _buildSectionHeader('Field Information', Icons.info_outline),

                          _buildInfoCard(
                            title: 'Field Number',
                            value: row[2],
                            icon: Icons.numbers,
                          ),

                          _buildInfoCard(
                            title: 'Region',
                            value: widget.region,
                            icon: Icons.location_on,
                          ),

                          const SizedBox(height: 20),
                          _buildSectionHeader('Audit Information', Icons.assignment),
                          _buildFIDropdownField('QA FI', 26),
                          const SizedBox(height: 10),
                          _buildTextFormField('Co-Rog', 27, icon: Icons.person),
                          const SizedBox(height: 10),
                          _buildDatePickerField('Date of Audit 1', 30, _dateAuditController),
                          const SizedBox(height: 10),
                          _buildDatePickerField('Rev Tgl Tanam', 32, _revTglTanamController),
                          const SizedBox(height: 10),
                          _buildText2FormField('Field Size by Audit (Ha)', 33),

                          const SizedBox(height: 10),
                          _buildSectionHeader('Previous Crop', Icons.skip_previous_rounded),
                          _buildDropdownFormField(
                            label: 'Previous Crop Actual',
                            items: previousCropActualItems,
                            value: selectedPreviousCropActual,
                            onChanged: (value) {
                              setState(() {
                                selectedPreviousCropActual = value;
                                row[34] = value ?? '';
                              });
                            },
                            helpText: 'A = Previous Crop not Corn\nB = Corn after corn with different trait\nC = Corn after Corn same trait',
                            icon: Icons.crop_rotate_rounded,
                            validator: (value) => (value == null || value.isEmpty) ? 'Previous Crop wajib dipilih' : null,
                          ),
                          const SizedBox(height: 10),
                          _buildSectionHeader('Isolation', Icons.straighten_rounded),
                          _buildDropdownFormField(
                            label: 'Isolation Audit 1',
                            items: isolationAudit1Items,
                            value: selectedIsolationAudit1,
                            onChanged: (value) {
                              setState(() {
                                selectedIsolationAudit1 = value;
                                row[35] = value ?? '';
                                // Jika N, hapus nilai isian terkait
                                if (value == 'N') {
                                  selectedIsolationType = null;
                                  row[36] = '';
                                  selectedIsolationDistance = null;
                                  row[37] = '';
                                }
                              });
                            },
                            helpText: 'Y = Yes\nN = No',
                            icon: Icons.content_paste_search_rounded,
                            validator: (value) => (value == null || value.isEmpty) ? 'Isolation Audit 1 wajib dipilih' : null,
                          ),
                          const SizedBox(height: 10),
                          if (selectedIsolationAudit1 == 'Y')
                            Column(
                              children: [
                                _buildDropdownFormField(
                                  label: 'Isolation Type',
                                  items: isolationTypeItems,
                                  value: selectedIsolationType,
                                  onChanged: (value) {
                                    setState(() {
                                      selectedIsolationType = value;
                                      row[36] = value ?? '';
                                    });
                                  },
                                  helpText: 'A = Other seed production\nB = Commercial',
                                  icon: Icons.type_specimen_rounded,
                                  validator: (value) => (selectedIsolationAudit1 == 'Y' && (value == null || value.isEmpty)) ? 'Isolation Type wajib dipilih' : null,
                                ),
                                const SizedBox(height: 10),
                                _buildDropdownFormField(
                                  label: 'Isolation Distance',
                                  items: isolationDistanceItems,
                                  value: selectedIsolationDistance,
                                  onChanged: (value) {
                                    setState(() {
                                      selectedIsolationDistance = value;
                                      row[37] = value ?? '';
                                    });
                                  },
                                  helpText: 'A = > 400\nB = <400',
                                  icon: Icons.straighten_rounded,
                                  validator: (value) => (selectedIsolationAudit1 == 'Y' && (value == null || value.isEmpty)) ? 'Isolation Distance wajib dipilih' : null,
                                ),
                                const SizedBox(height: 10),
                              ],
                            ),
                          const SizedBox(height: 10),
                          _buildSectionHeader('Offtype & Volunteer', Icons.warning_rounded),
                          _buildText2FormField('Audit 1 Offtype', 38),
                          const SizedBox(height: 10),
                          _buildText2FormField('Audit 1 Volunteer', 39),

                          const SizedBox(height: 10),
                          _buildSectionHeader('Crop Quality', Icons.health_and_safety_rounded),
                          const SizedBox(height: 10),
                          _buildDropdownFormField(
                            label: 'Crop Health',
                            items: cropHealthItems,
                            value: selectedCropHealth,
                            onChanged: (value) {
                              setState(() {
                                selectedCropHealth = value;
                                row[40] = value ?? '';
                              });
                            },
                            helpText: '1 (Very Poor)\n2 (Poor)\n3 (Fair)\n4 (Good)\n5 (Best)',
                            icon: Icons.monitor_heart_rounded,
                            validator: (value) => (value == null || value.isEmpty) ? 'Crop Health wajib dipilih' : null,
                          ),

                          const SizedBox(height: 10),

                          _buildDropdownFormField(
                            label: 'Crop Uniformity',
                            items: cropUniformityItems,
                            value: selectedCropUniformity,
                            onChanged: (value) {
                              setState(() {
                                selectedCropUniformity = value;
                                row[41] = value ?? '';
                              });
                            },
                            helpText: '1 (Very Poor)\n2 (Poor)\n3 (Fair)\n4 (Good)\n5 (Best)',
                            icon: Icons.grain,
                            validator: (value) => (value == null || value.isEmpty) ? 'Crop Uniformity wajib dipilih' : null,
                          ),

                          const SizedBox(height: 30),
                          Center(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                // Memvalidasi form sebelum menyimpan
                                if (_formKey.currentState!.validate()) {
                                  // Jika form valid, lanjutkan proses penyimpanan
                                  _showLoadingAndSaveInBackground();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(220, 60),
                                backgroundColor: Colors.orange.shade700,
                                foregroundColor: Colors.white,
                                elevation: 5,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              icon: const Icon(Icons.save, size: 26, color: Colors.white),
                              label: const Text(
                                'Simpan',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextFormField(String label, int index, {IconData? icon, int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(51),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        initialValue: row[index],
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.orange.shade700),
          prefixIcon: icon != null ? Icon(icon, color: Colors.orange.shade600) : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.orange.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.orange.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.orange.shade700, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        onChanged: (value) {
          setState(() {
            row[index] = value;
          });
        },
        // VALIDATOR ditambahkan di sini
        validator: (value) {
          if (isDiscardMode) {
            return null; // Tidak wajib jika mode discard aktif
          }
          if (value == null || value.isEmpty) {
            return '$label wajib diisi';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildText2FormField(String label, int index, {IconData? icon}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(51),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        initialValue: row[index].isNotEmpty ? "'${row[index]}" : "'0",
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.orange.shade700),
          prefixIcon: icon != null ? Icon(icon, color: Colors.orange.shade600) : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.orange.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.orange.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.orange.shade700, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        onChanged: (value) {
          setState(() {
            String cleanedValue = value.replaceAll("'", "");
            row[index] = "'$cleanedValue";
          });
        },
        // VALIDATOR ditambahkan di sini
        validator: (value) {
          if (isDiscardMode) {
            return null; // Tidak wajib jika mode discard aktif
          }
          if (value == null || value.isEmpty || value == "'") {
            return '$label wajib diisi';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.orange.shade800, size: 24),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade800,
              ),
            ),
          ],
        ),
        const Divider(thickness: 2, color: Colors.orange),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildInfoCard({required String title, required String value, required IconData icon}) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(icon, color: Colors.orange.shade700),
            const SizedBox(width: 10),
            Expanded( // Menambahkan Expanded untuk menghindari overflow
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                    overflow: TextOverflow.ellipsis, // Menghindari teks keluar
                    maxLines: 1, // Membatasi jumlah baris
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis, // Menghindari teks keluar
                    maxLines: 1, // Membatasi jumlah baris
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFIDropdownField(String label, int index) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(51),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.orange.shade700),
          prefixIcon: Icon(Icons.person, color: Colors.orange.shade600),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.orange.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.orange.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.orange.shade700, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        initialValue: selectedFI,
        items: fiList.map((String fi) {
          return DropdownMenuItem<String>(
            value: fi,
            child: SizedBox(
              width: double.infinity, // Memastikan lebar penuh
              child: Text(
                fi,
                overflow: TextOverflow.ellipsis, // Menghindari teks keluar
                maxLines: 1, // Membatasi jumlah baris
              ),
            ),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            selectedFI = value;
            row[index] = value ?? '';
          });
        },
        dropdownColor: Colors.white,
        icon: Icon(Icons.arrow_drop_down, color: Colors.orange.shade700),
        isExpanded: true, // Memastikan dropdown mengisi ruang yang tersedia
        // VALIDATOR ditambahkan di sini
        validator: (value) {
          if (isDiscardMode) {
            return null; // Tidak wajib jika mode discard aktif
          }
          if (value == null || value.isEmpty) {
            return '$label wajib dipilih';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDatePickerField(String label, int index, TextEditingController controller) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(51),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.orange.shade700),
          prefixIcon: Icon(Icons.calendar_today, color: Colors.orange.shade600),
          suffixIcon: Icon(Icons.arrow_drop_down, color: Colors.orange.shade700),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.orange.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.orange.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.orange.shade700, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        onTap: () async {
          DateTime? pickedDate = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2101),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.light(
                    primary: Colors.orange.shade700,
                    onPrimary: Colors.white,
                    onSurface: Colors.black,
                  ),
                ),
                child: child!,
              );
            },
          );

          if (pickedDate != null) {
            String formattedDate = DateFormat('dd/MM/yyyy').format(pickedDate);
            setState(() {
              controller.text = formattedDate;
              row[index] = formattedDate; // index = 30 untuk Date of Audit 1

              // --- LOGIKA OTOMATISASI BARU ---
              if (isDiscardMode) {
                // Otomatis isi tanggal untuk Audit 2 (indeks 44) dan Audit 3 (indeks 53)
                if (row.length > 44) {
                  row[44] = formattedDate;
                }
                if (row.length > 53) {
                  row[53] = formattedDate;
                }
                debugPrint('Mode Discard Aktif: Tanggal Audit 2 & 3 diatur otomatis.');
              }
              // --- AKHIR LOGIKA OTOMATISASI ---
            });
          }
        },
        // VALIDATOR ditambahkan di sini
        validator: (value) {
          if (value == null || value.isEmpty) {
            return '$label wajib dipilih';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDropdownFormField({
    required String label,
    required List<String> items,
    required String? value,
    required Function(String?) onChanged,
    String? hint,
    String? helpText,
    IconData? icon,
    // Menambahkan parameter validator
    String? Function(String?)? validator,
  }) {
    if (value != null && !items.contains(value)) {
      value = null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withAlpha(51),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(color: Colors.orange.shade700),
              prefixIcon: icon != null ? Icon(icon, color: Colors.orange.shade600) : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.orange.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.orange.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.orange.shade700, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            initialValue: value,
            hint: Text(hint ?? 'Select an option'),
            onChanged: onChanged,
            items: items.map<DropdownMenuItem<String>>((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(item),
              );
            }).toList(),
            dropdownColor: Colors.white,
            icon: Icon(Icons.arrow_drop_down, color: Colors.orange.shade700),
            // Menggunakan validator yang dilewatkan
            validator: validator,
          ),
        ),
        if (helpText != null) ...[
          const SizedBox(height: 5),
          Text(
            helpText,
            style: const TextStyle(
              fontStyle: FontStyle.italic,
              color: Colors.grey,
            ),
          ),
        ],
      ],
    );
  }

  void _showLoadingDialogAndClose() {
    bool dialogShown = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        dialogShown = true;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset('assets/loading.json', width: 150, height: 150),
              const SizedBox(height: 20),
              const Text(
                "Ngrantos sekedap...",
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
        );
      },
    );

    Timer(const Duration(seconds: 5), () {
      if (dialogShown && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        Future.microtask(() {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => PspSuccessScreen(
                  row: row,
                  userName: userName,
                  userEmail: userEmail,
                  region: widget.region,
                ),
              ),
            );
          }
        });
      }
    });
  }

  void _showLoadingAndSaveInBackground() {
    _showLoadingDialogAndClose();
    _saveToHive(row);
    _saveToGoogleSheets(row);
  }

  Future<void> _saveToGoogleSheets(List<String> rowData) async {
    setState(() => isLoading = true);

    String responseMessage;
    try {
      await gSheetsApi.updateRow('Vegetative', rowData, rowData[2]);
      await _saveToHive(rowData);
      responseMessage = 'Data successfully saved to Audit Database';

      final Worksheet? sheet = gSheetsApi.spreadsheet.worksheetByTitle('Vegetative');
      if (sheet != null) {
        final rowIndex = await _findRowByFieldNumber(sheet, row[2]);
        if (rowIndex != -1) {
          await _restoreVegetativeFormulas(gSheetsApi, sheet, rowIndex);
        }
      }
    } catch (e) {
      await _logErrorToActivity('Gagal menyimpan data: ${e.toString()}');
      responseMessage = 'Failed to save data. Please try again.';
    } finally {
      setState(() {
        isLoading = false; // Sembunyikan loader
      });
    }

    if (mounted) _navigateBasedOnResponse(context, responseMessage);
  }

  Future<void> _restoreVegetativeFormulas(GoogleSheetsApi gSheetsApi, Worksheet sheet, int rowIndex) async {
    await sheet.values.insertValue( // Cek Audit 1
        '=IF(OR(AE$rowIndex=0;AE$rowIndex="");"NOT Audited";"Audited")',
        row: rowIndex, column: 84);
    await sheet.values.insertValue( // Cek Audit 2
        '=IF(OR(AS$rowIndex=0;AS$rowIndex="");"NOT Audited";"Audited")',
        row: rowIndex, column: 86);
    await sheet.values.insertValue( // Cek Audit 3
        '=IF(OR(BB$rowIndex=0;BB$rowIndex="");"NOT Audited";"Audited")',
        row: rowIndex, column: 88);
    await sheet.values.insertValue( // Cek Audit 4
        '=IF(OR(BK$rowIndex=0;BK$rowIndex="");"NOT Audited";"Audited")',
        row: rowIndex, column: 90);
    debugPrint("Rumus berhasil diterapkan di Vegetative pada baris $rowIndex.");
  }

  Future<int> _findRowByFieldNumber(Worksheet sheet, String fieldNumber) async {
    final List<List<String>> rows = await sheet.values.allRows();
    for (int i = 0; i < rows.length; i++) {
      if (rows[i].isNotEmpty && rows[i][2] == fieldNumber) {
        return i + 1;
      }
    }
    return -1;
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _navigateBasedOnResponse(BuildContext context, String response) {
    if (response == 'Data successfully saved to Audit Database') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => PspSuccessScreen(
            row: row,
            userName: userName,
            userEmail: userEmail,
            region: widget.region,
          ),
        ),
      );
    } else if (response == 'Failed to save data. Please try again.') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => PspFailedScreen(),
        ),
      );
    } else {
      _showSnackbar('Unknown response: $response');
    }
  }

  String _convertToDateIfNecessary(String value) {
    try {
      final parsedNumber = double.tryParse(value);
      if (parsedNumber != null) {
        final date = DateTime(1899, 12, 30).add(Duration(days: parsedNumber.toInt()));
        return DateFormat('dd/MM/yyyy').format(date);
      }
    } catch (e) {
      // jeda
    }
    return value;
  }
}

class PspSuccessScreen extends StatelessWidget {
  final List<String> row;
  final String userName;
  final String userEmail;
  final String region;

  const PspSuccessScreen({
    super.key,
    required this.row,
    required this.userName,
    required this.userEmail,
    required this.region,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Success',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.orange,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.orange, size: 100),
            const SizedBox(height: 20),
            const Text(
              'Data berhasil disimpan!',
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                _showLoadingDialog(context);
                final navigator = Navigator.of(context);
                await _saveBackActivityToGoogleSheets(region);
                navigator.pop();
                navigator.pop();
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 60), // Mengatur ukuran tombol (lebar x tinggi)
                backgroundColor: Colors.orange, // Warna background tombol
                foregroundColor: Colors.white, // Warna teks tombol
                shape: RoundedRectangleBorder( // Membuat sudut tombol melengkung
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                'Confirm!',
                style: TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Fungsi untuk menampilkan dialog loading
  void _showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset('assets/loading.json', width: 150, height: 150),
              const SizedBox(height: 20),
              const Text(
                "Ngrantos sekedap...",
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveBackActivityToGoogleSheets(String region) async {
    final String spreadsheetId = ConfigManager.getSpreadsheetId(region) ?? 'defaultSpreadsheetId';
    final String worksheetTitle = 'Aktivitas';

    final gSheetsApi = GoogleSheetsApi(spreadsheetId);
    await gSheetsApi.init();

    final String timestamp = DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());
    final String fieldNumber = row[2];
    final String action = 'Update';
    final String status = 'Success';

    final List<String> rowData = [
      userEmail,
      userName,
      status,
      'PSP Audit 1',
      action,
      'Vegetative',
      fieldNumber,
      timestamp,
    ];

    try {
      await gSheetsApi.addRow(worksheetTitle, rowData);
      debugPrint('Aktivitas berhasil dicatat di Database $worksheetTitle');
    } catch (e) {
      debugPrint('Gagal mencatat aktivitas di Database $worksheetTitle: $e');
    }
  }
}

class PspFailedScreen extends StatelessWidget {
  const PspFailedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Failed',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.orange.shade700,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 100),
            const SizedBox(height: 20),
            const Text(
              'Failed to save data. Please try again.',
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 60), // Mengatur ukuran tombol (lebar x tinggi)
                backgroundColor: Colors.orange.shade700, // Warna background tombol
                foregroundColor: Colors.white, // Warna teks tombol
                shape: RoundedRectangleBorder( // Membuat sudut tombol melengkung
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                'Back',
                style: TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _logErrorToActivity(String message) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  List<String> logs = prefs.getStringList('activityLogs') ?? [];
  logs.add('${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())}: $message');
  await prefs.setStringList('activityLogs', logs);
}