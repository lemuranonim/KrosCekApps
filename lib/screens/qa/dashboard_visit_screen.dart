import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'dart:io'; // Untuk File
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';
import 'package:flutter_downloader/flutter_downloader.dart';
import '../services/google_sheets_api.dart';

// Definisikan AppTheme jika belum ada (atau impor)
class AppTheme {
  static const Color primary = Colors.green;
  static const Color secondary = Color(0xFF4CAF50);
  static const Color accent = Color(0xFF8BC34A);
  static const Color background = Color(0xFFF5F5F5);
  static const Color cardBackground = Colors.white;
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color divider = Color(0xFFBDBDBD);

  static const double borderRadius = 12.0;
  static const double cardElevation = 4.0;

  static BoxShadow cardShadow = BoxShadow(
    color: Colors.black.withAlpha(25),
    blurRadius: 8,
    offset: const Offset(0, 2),
  );

  static ThemeData get theme => ThemeData(
    primaryColor: primary,
    scaffoldBackgroundColor: background,
    appBarTheme: const AppBarTheme(
      backgroundColor: primary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),
    cardTheme: CardThemeData(
      color: cardBackground,
      elevation: cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius / 2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius / 2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius / 2),
        borderSide: BorderSide(color: divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius / 2),
        borderSide: BorderSide(color: divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius / 2),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
  );
}

// Model untuk menyimpan data yang sudah diproses per Field Number
class VisitData {
  final String fieldNumber;
  int vegetativeVisits;
  int generative1Visits;
  int generative2Visits;
  int generative3Visits;
  int preHarvestVisits;
  int harvestVisits;
  String? uniformityVeg;
  String? uniformityGen1;
  String? uniformityGen2;
  String? uniformityGen3;
  String? uniformityPre;
  String? uniformityHar;
  Set<String> inspectedByFIs; // Menyimpan daftar FI yang menginspeksi field ini

  VisitData({
    required this.fieldNumber,
    this.vegetativeVisits = 0,
    this.generative1Visits = 0,
    this.generative2Visits = 0,
    this.generative3Visits = 0,
    this.preHarvestVisits = 0,
    this.harvestVisits = 0,
    this.uniformityVeg,
    this.uniformityGen1,
    this.uniformityGen2,
    this.uniformityGen3,
    this.uniformityPre,
    this.uniformityHar,
    Set<String>? inspectedByFIs, // Diubah menjadi opsional dengan default
  }) : inspectedByFIs = inspectedByFIs ?? <String>{}; // Default ke Set kosong
}

class DashboardVisitScreen extends StatefulWidget {
  final String selectedRegion;
  final String spreadsheetId;

  const DashboardVisitScreen({
    super.key,
    required this.selectedRegion,
    required this.spreadsheetId,
  });

  @override
  State<DashboardVisitScreen> createState() => _DashboardVisitScreenState();
}

class _DashboardVisitScreenState extends State<DashboardVisitScreen> {
  late GoogleSheetsApi _googleSheetsApi;
  bool _isLoading = true;
  String? _errorMessage;

  List<VisitData> _filteredDisplayData = [];

  // State untuk filter
  String? _selectedFI;
  List<String> _availableFIs = [];

  // State untuk DataTable2
  int _rowsPerPage = PaginatedDataTable.defaultRowsPerPage;
  int? _sortColumnIndex;
  bool _sortAscending = true;
  PaginatorController? _paginatorController;

  // Indeks Kolom yang telah disepakati (0-based)
  // Worksheet 'Aktivitas'
  final int colAktivitasSheetName = 5;  // F
  final int colAktivitasFieldNo = 6;    // G
  final int colAktivitasFI = 1; // B (Nama Field Inspector)

  // Worksheet Fase
  final int colFaseFieldNo = 2;         // C (Field Number)
  final int colVegUniformity = 43;    // AR
  final int colGen1Uniformity = 40;   // AO
  final int colGen2Uniformity = 46;   // AU
  final int colGen3Uniformity = 64;   // BM
  final int colPreHarvUniformity = 33;// AH
  final int colHarvUniformity = 33;   // AH (Harvest)

  // Cache data to avoid repeated API calls
  Map<String, List<List<String>>> _worksheetDataCache = {};

  @override
  void initState() {
    super.initState();
    _googleSheetsApi = GoogleSheetsApi(widget.spreadsheetId);
    _paginatorController = PaginatorController();

    // Register callback for download status
    FlutterDownloader.registerCallback(downloadCallback, step: 1);

    _loadInitialData();
  }

  @pragma('vm:entry-point') // This is important to prevent tree shaking in release mode
  static void downloadCallback(String id, int status, int progress) {
    // Convert the status integer to DownloadTaskStatus enum if needed
    final DownloadTaskStatus statusEnum = DownloadTaskStatus.values[status];
    debugPrint('Download task ($id) is in status: $statusEnum and progress: $progress');
  }

  @override
  void dispose() {
    // Don't pass null to unregister - just don't call this if you want to unregister
    // FlutterDownloader.registerCallback(null);
    super.dispose();
  }

  Future<void> _saveFile(dynamic content, String fileName, String mimeType) async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String localFilePath = '${tempDir.path}/$fileName';
      final File localFile = File(localFilePath);

      if (content is String) {
        await localFile.writeAsString(content);
      } else if (content is List<int>) {
        await localFile.writeAsBytes(Uint8List.fromList(content));
      } else {
        if (mounted) {
          _showErrorSnackBar('Format konten tidak didukung untuk disimpan.');
        }
        return;
      }

      // Get the download directory path
      final downloadPath = await _findDownloadPath();
      if (downloadPath == null) {
        if (mounted) {
          _showErrorSnackBar('Tidak dapat menemukan direktori unduhan.');
        }
        return;
      }

      // Start the download task
      final taskId = await FlutterDownloader.enqueue(
        url: 'file://$localFilePath',
        savedDir: downloadPath,
        fileName: fileName,
        showNotification: true,
        openFileFromNotification: true,
        saveInPublicStorage: true,
      );

      // Store the taskId if you need to track this specific download
      debugPrint('Download started with taskId: $taskId');

      if (mounted) {
        _showSuccessSnackBar('File "$fileName" sedang diunduh ke folder Downloads.');
      }

      // Delete the temporary file after it's been queued for download
      if (await localFile.exists()) {
        await localFile.delete();
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Gagal menyimpan file: ${e.toString()}');
      }
      debugPrint('Error saat menyimpan file dengan FlutterDownloader: $e');
    }
  }

// Add this helper method to find the download directory
  Future<String?> _findDownloadPath() async {
    if (Platform.isAndroid) {
      return '/storage/emulated/0/Download';
    } else if (Platform.isIOS) {
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    }
    return null;
  }

  // Initial data loading - separate from filtering
  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _googleSheetsApi.init();
      await _loadAllWorksheetData();
      await _processAllData();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error in _loadInitialData: ${e.toString()}");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Gagal memuat data: ${e.toString()}";
        });
      }
    }
  }

  // Load all worksheet data once and cache it
  Future<void> _loadAllWorksheetData() async {
    // Clear the cache
    _worksheetDataCache = {};

    // Load Aktivitas data
    _worksheetDataCache['Aktivitas'] = await _googleSheetsApi.getSpreadsheetData('Aktivitas');

    // Load phase worksheets
    _worksheetDataCache['Vegetative'] = await _googleSheetsApi.getSpreadsheetData('Vegetative');
    _worksheetDataCache['Generative'] = await _googleSheetsApi.getSpreadsheetData('Generative');
    _worksheetDataCache['Pre Harvest'] = await _googleSheetsApi.getSpreadsheetData('Pre Harvest');
    _worksheetDataCache['Harvest'] = await _googleSheetsApi.getSpreadsheetData('Harvest');
  }

  // Process all data with or without FI filter
  Future<void> _processAllData() async {
    if (!mounted) return;

    setState(() {
      _filteredDisplayData = [];
    });

    try {
      // Get the cached Aktivitas data
      final List<List<String>> aktivitasData = _worksheetDataCache['Aktivitas'] ?? [];

      // Extract all FIs for the dropdown
      Set<String> uniqueFIs = {};
      for (int i = 1; i < aktivitasData.length; i++) {
        if (i >= aktivitasData.length) continue;
        var row = aktivitasData[i];
        if (row.length <= colAktivitasFI) continue;

        String fiName = row[colAktivitasFI].trim();
        if (fiName.isNotEmpty) {
          uniqueFIs.add(fiName);
        }
      }

      // Update available FIs
      List<String> sortedUniqueFIs = uniqueFIs.toList()..sort();
      if (!_listEquals(_availableFIs, sortedUniqueFIs)) {
        setState(() {
          _availableFIs = sortedUniqueFIs;
        });
      }

      // Process visit data
      Map<String, VisitData> fieldVisitMap = {};

      // First pass: collect all field numbers and their FIs
      for (int i = 1; i < aktivitasData.length; i++) {
        if (i >= aktivitasData.length) continue;
        var row = aktivitasData[i];
        if (row.length <= colAktivitasFieldNo || row.length <= colAktivitasSheetName || row.length <= colAktivitasFI) continue;

        String fieldNo = row[colAktivitasFieldNo].trim();
        String fiName = row[colAktivitasFI].trim();

        if (fieldNo.isEmpty) continue;

        // Create or get the VisitData object
        if (!fieldVisitMap.containsKey(fieldNo)) {
          fieldVisitMap[fieldNo] = VisitData(fieldNumber: fieldNo);
        }

        // Add the FI to the field's inspectors
        if (fiName.isNotEmpty) {
          fieldVisitMap[fieldNo]!.inspectedByFIs.add(fiName);
        }
      }

      // Second pass: filter by selected FI if needed and count visits
      Map<String, VisitData> filteredFieldVisitMap = {};

      for (var entry in fieldVisitMap.entries) {
        String fieldNo = entry.key;
        VisitData visitData = entry.value;

        // Apply FI filter if selected
        if (_selectedFI != null && _selectedFI!.isNotEmpty) {
          if (!visitData.inspectedByFIs.contains(_selectedFI)) {
            continue; // Skip this field if it wasn't inspected by the selected FI
          }
        }

        // This field passes the filter, add it to filtered map
        filteredFieldVisitMap[fieldNo] = visitData;
      }

      // Third pass: count visits for filtered fields
      for (int i = 1; i < aktivitasData.length; i++) {
        if (i >= aktivitasData.length) continue;
        var row = aktivitasData[i];
        if (row.length <= colAktivitasFieldNo || row.length <= colAktivitasSheetName) continue;

        String fieldNo = row[colAktivitasFieldNo].trim();
        String sheetName = row[colAktivitasSheetName].trim().toLowerCase();

        // Skip if this field isn't in our filtered map
        if (!filteredFieldVisitMap.containsKey(fieldNo)) continue;

        // Count the visit based on sheet name
        if (sheetName.contains('vegetative')) {
          filteredFieldVisitMap[fieldNo]!.vegetativeVisits++;
        } else if (sheetName.contains('generative - audit 1')) {
          filteredFieldVisitMap[fieldNo]!.generative1Visits++;
        } else if (sheetName.contains('generative - audit 2')) {
          filteredFieldVisitMap[fieldNo]!.generative2Visits++;
        } else if (sheetName.contains('generative - audit 3')) {
          filteredFieldVisitMap[fieldNo]!.generative3Visits++;
        } else if (sheetName.contains('pre harvest')) {
          filteredFieldVisitMap[fieldNo]!.preHarvestVisits++;
        } else if (sheetName.contains('harvest')) {
          filteredFieldVisitMap[fieldNo]!.harvestVisits++;
        }
      }

      // Fourth pass: get uniformity data for filtered fields
      await _processUniformityData(filteredFieldVisitMap);

      // Update the data lists
      List<VisitData> processedData = filteredFieldVisitMap.values.toList();

      if (mounted) {
        setState(() {
          _filteredDisplayData = processedData;
        });
      }

    } catch (e) {
      debugPrint("Error in _processAllData: ${e.toString()}");
      if (mounted) {
        setState(() {
          _errorMessage = "Gagal memproses data: ${e.toString()}";
        });
      }
    }
  }

  // Process uniformity data for all filtered fields
  Future<void> _processUniformityData(Map<String, VisitData> fieldVisitMap) async {
    try {
      // Process Vegetative uniformity
      await _processWorksheetUniformity(
          fieldVisitMap,
          'Vegetative',
          colFaseFieldNo,
          colVegUniformity,
              (visitData, value) => visitData.uniformityVeg = value
      );

      // Process Generative uniformities
      await _processWorksheetUniformity(
          fieldVisitMap,
          'Generative',
          colFaseFieldNo,
          colGen1Uniformity,
              (visitData, value) => visitData.uniformityGen1 = value
      );

      await _processWorksheetUniformity(
          fieldVisitMap,
          'Generative',
          colFaseFieldNo,
          colGen2Uniformity,
              (visitData, value) => visitData.uniformityGen2 = value
      );

      await _processWorksheetUniformity(
          fieldVisitMap,
          'Generative',
          colFaseFieldNo,
          colGen3Uniformity,
              (visitData, value) => visitData.uniformityGen3 = value
      );

      // Process Pre Harvest uniformity
      await _processWorksheetUniformity(
          fieldVisitMap,
          'Pre Harvest',
          colFaseFieldNo,
          colPreHarvUniformity,
              (visitData, value) => visitData.uniformityPre = value
      );

      // Process Harvest uniformity
      await _processWorksheetUniformity(
          fieldVisitMap,
          'Harvest',
          colFaseFieldNo,
          colHarvUniformity,
              (visitData, value) => visitData.uniformityHar = value
      );

    } catch (e) {
      debugPrint("Error in _processUniformityData: ${e.toString()}");
      // Continue even if there's an error with uniformity data
    }
  }

  // Process uniformity data from a specific worksheet
  Future<void> _processWorksheetUniformity(
      Map<String, VisitData> fieldVisitMap,
      String worksheetName,
      int fieldNoColumn,
      int uniformityColumn,
      Function(VisitData, String) updateFunction
      ) async {
    try {
      final List<List<String>> worksheetData = _worksheetDataCache[worksheetName] ?? [];

      for (int i = 1; i < worksheetData.length; i++) {
        if (i >= worksheetData.length) continue;
        var row = worksheetData[i];
        if (row.length <= fieldNoColumn) continue;

        String fieldNo = row[fieldNoColumn].trim();

        // Skip if this field isn't in our filtered map
        if (!fieldVisitMap.containsKey(fieldNo)) continue;

        // Get uniformity value if the column exists
        String uniformityValue = '';
        if (row.length > uniformityColumn) {
          uniformityValue = row[uniformityColumn].trim();
        }

        // Update the visit data with uniformity value
        updateFunction(fieldVisitMap[fieldNo]!, uniformityValue);
      }
    } catch (e) {
      debugPrint("Error processing $worksheetName uniformity: ${e.toString()}");
      // Continue even if there's an error with one worksheet
    }
  }

  // Apply FI filter when dropdown selection changes
  void _applyFIFilter(String? selectedFI) {
    setState(() {
      _selectedFI = selectedFI;
      _isLoading = true;
    });

    // Process data with the new filter
    _processAllData().then((_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }).catchError((error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Gagal menerapkan filter: ${error.toString()}";
        });
      }
    });
  }

  // Refresh all data
  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _loadAllWorksheetData();
      await _processAllData();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Gagal memuat ulang data: ${e.toString()}";
        });
      }
    }
  }

  void _sort<T>(Comparable<T> Function(VisitData d) getField, int columnIndex, bool ascending) {
    try {
      _filteredDisplayData.sort((a, b) {
        final Comparable<T> valueA = getField(a);
        final Comparable<T> valueB = getField(b);
        return ascending ? Comparable.compare(valueA, valueB) : Comparable.compare(valueB, valueA);
      });
      setState(() {
        _sortColumnIndex = columnIndex;
        _sortAscending = ascending;
      });
    } catch (e) {
      debugPrint("Error sorting data: ${e.toString()}");
      // Don't update sort state if there was an error
    }
  }

  Future<void> _exportToCsv() async {
    bool permissionGranted = await _requestStoragePermission();
    if (!permissionGranted) {
      // Show the SnackBar only if the context is still valid
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Izin penyimpanan ditolak.')),
        );
      }
      return; // Exit the function if permission is not granted
    }

    // Proceed with CSV export if permission is granted
    List<List<dynamic>> rows = [];
    // Header
    rows.add([
      "FIELD NUMBER", "VEGETATIVE", "CROP UNIFORMITY (VEG.)",
      "GENERATIVE 1", "CROP UNIFORMITY (GEN. 1)",
      "GENERATIVE 2", "CROP UNIFORMITY (GEN. 2)",
      "GENERATIVE 3", "CROP UNIFORMITY (GEN. 3)",
      "PRE HARVEST", "CROP UNIFORMITY (PRE)",
      "HARVEST", "CROP UNIFORMITY (HAR)"
    ]);

    for (var data in _filteredDisplayData) {
      rows.add([
        data.fieldNumber,
        data.vegetativeVisits, data.uniformityVeg ?? '',
        data.generative1Visits, data.uniformityGen1 ?? '',
        data.generative2Visits, data.uniformityGen2 ?? '',
        data.generative3Visits, data.uniformityGen3 ?? '',
        data.preHarvestVisits, data.uniformityPre ?? '',
        data.harvestVisits, data.uniformityHar ?? '',
      ]);
    }

    String csv = const ListToCsvConverter().convert(rows);
    await _saveFile(csv, "dashboard_visit_data.csv", "text/csv");
  }

  Future<void> _exportToXlsx() async {
    bool permissionGranted = await _requestStoragePermission();
    if (!permissionGranted) {
      // Show the SnackBar only if the context is still valid
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Izin penyimpanan ditolak.')),
        );
      }
      return; // Exit the function if permission is not granted
    }

    // Proceed with XLSX export if permission is granted
    var excel = excel_lib.Excel.createExcel();
    excel_lib.Sheet sheetObject = excel['DashboardVisit'];

    // Header
    sheetObject.appendRow([
      excel_lib.TextCellValue("FIELD NUMBER"),
      excel_lib.TextCellValue("VEGETATIVE"), excel_lib.TextCellValue("CROP UNIFORMITY (VEG.)"),
      excel_lib.TextCellValue("GENERATIVE 1"), excel_lib.TextCellValue("CROP UNIFORMITY (GEN. 1)"),
      excel_lib.TextCellValue("GENERATIVE 2"), excel_lib.TextCellValue("CROP UNIFORMITY (GEN. 2)"),
      excel_lib.TextCellValue("GENERATIVE 3"), excel_lib.TextCellValue("CROP UNIFORMITY (GEN. 3)"),
      excel_lib.TextCellValue("PRE HARVEST"), excel_lib.TextCellValue("CROP UNIFORMITY (PRE)"),
      excel_lib.TextCellValue("HARVEST"), excel_lib.TextCellValue("CROP UNIFORMITY (HAR)"),
    ]);

    for (var data in _filteredDisplayData) {
      sheetObject.appendRow([
        excel_lib.TextCellValue(data.fieldNumber),
        excel_lib.IntCellValue(data.vegetativeVisits), excel_lib.TextCellValue(data.uniformityVeg ?? ''),
        excel_lib.IntCellValue(data.generative1Visits), excel_lib.TextCellValue(data.uniformityGen1 ?? ''),
        excel_lib.IntCellValue(data.generative2Visits), excel_lib.TextCellValue(data.uniformityGen2 ?? ''),
        excel_lib.IntCellValue(data.generative3Visits), excel_lib.TextCellValue(data.uniformityGen3 ?? ''),
        excel_lib.IntCellValue(data.preHarvestVisits), excel_lib.TextCellValue(data.uniformityPre ?? ''),
        excel_lib.IntCellValue(data.harvestVisits), excel_lib.TextCellValue(data.uniformityHar ?? ''),
      ]);
    }

    var fileBytes = excel.save();
    if (fileBytes != null) {
      await _saveFile(fileBytes, "dashboard_visit_data.xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
    }
  }

  void _showPermissionDeniedDialog(String message) {
    // Pastikan context masih valid sebelum menampilkan dialog
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog( // Menggunakan dialogContext
        title: const Text("Izin Diperlukan"),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            child: const Text("Batal"),
            onPressed: () => Navigator.of(dialogContext).pop(), // Menggunakan dialogContext
          ),
          TextButton(
            child: const Text("Pengaturan"),
            onPressed: () {
              openAppSettings(); // Fungsi dari permission_handler untuk membuka pengaturan aplikasi
              Navigator.of(dialogContext).pop(); // Menggunakan dialogContext
            },
          ),
        ],
      ),
    );
  }

  Future<bool> _requestStoragePermission() async {
    if (!mounted) return false;

    if (!Platform.isAndroid) {
      return true;
    }

    // For Android 13+ (API level 33+), we need to request specific permissions
    if (await Permission.storage.status.isGranted) {
      return true;
    }

    // If permission is permanently denied, direct user to settings
    if (await Permission.storage.isPermanentlyDenied) {
      _showPermissionDeniedDialog(
          "Izin penyimpanan telah ditolak secara permanen. Harap aktifkan dari pengaturan aplikasi untuk menyimpan file.");
      return false;
    }

    // Request permission
    final status = await Permission.storage.request();

    if (status.isGranted) {
      return true;
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Izin penyimpanan diperlukan untuk menyimpan file.')),
        );
      }
      return false;
    }
  }

  // Replace your current ScaffoldMessenger.of(context).showSnackBar calls with this:
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
        action: SnackBarAction(
          label: 'VIEW',
          textColor: Colors.white,
          onPressed: () {
            // Add your file open logic here
          },
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard Visit (${widget.selectedRegion})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh Data',
            onPressed: _isLoading ? null : _refreshData,
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(51),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.file_download, color: Colors.white),
              tooltip: 'Download Data',
              onPressed: (_isLoading || _filteredDisplayData.isEmpty) ? null : () {
                showDialog(
                  context: context,
                  builder: (context) => Dialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                    backgroundColor: Colors.transparent,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.rectangle,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10.0,
                            offset: Offset(0.0, 10.0),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "Choose Download Format",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withAlpha(25),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.description, color: Colors.blue[700], size: 28),
                              ),
                              title: Text(
                                "CSV Format",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                              ),
                              subtitle: const Text(
                                "Comma Separated Values - Compatible with most spreadsheet applications",
                                style: TextStyle(fontSize: 12),
                              ),
                              trailing: Icon(Icons.arrow_forward_ios, color: Colors.blue[700], size: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              onTap: () {
                                Navigator.pop(context);
                                _exportToCsv(); // Call the CSV export function
                              },
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.green.withAlpha(25),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.table_chart, color: Colors.green[700], size: 28),
                              ),
                              title: Text(
                                "Excel Format",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[700],
                                ),
                              ),
                              subtitle: const Text(
                                "XLSX - Native Microsoft Excel format with full formatting",
                                style: TextStyle(fontSize: 12),
                              ),
                              trailing: Icon(Icons.arrow_forward_ios, color: Colors.green[700], size: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              onTap: () {
                                Navigator.pop(context);
                                _exportToXlsx(); // Call the XLSX export function
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              "Cancel",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Memuat data...", style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text("Coba Lagi"),
              onPressed: _refreshData,
            )
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: 'Filter Field Inspector (FI)',
              hintText: 'Pilih FI untuk filter',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.borderRadius)),
              prefixIcon: const Icon(Icons.person_search),
              filled: true,
              fillColor: AppTheme.cardBackground,
            ),
            initialValue: _selectedFI,
            items: [
              const DropdownMenuItem<String>(value: null, child: Text("Semua FI")),
              ..._availableFIs.map((fi) => DropdownMenuItem<String>(value: fi, child: Text(fi))),
            ],
            onChanged: _isLoading ? null : _applyFIFilter,
          ),
        ),

        // Enhanced DataTable
        Expanded(
          child: Card(
            margin: const EdgeInsets.all(16.0),
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: PaginatedDataTable2(
                controller: _paginatorController,
                horizontalMargin: 16,
                checkboxHorizontalMargin: 8,
                columnSpacing: 16,
                wrapInCard: false,
                header: const Text(
                  'Field Visit Summary',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppTheme.primary,
                  ),
                ),
                columns: [
                  DataColumn2(
                      label: const Text('Field Number', style: TextStyle(fontWeight: FontWeight.bold)),
                      size: ColumnSize.M,
                      onSort: (columnIndex, ascending) => _sort<String>((d) => d.fieldNumber, columnIndex, ascending)
                  ),
                  DataColumn2(
                      label: const Text('Veg', style: TextStyle(fontWeight: FontWeight.bold)),
                      numeric: true,
                      size: ColumnSize.S,
                      onSort: (columnIndex, ascending) => _sort<num>((d) => d.vegetativeVisits, columnIndex, ascending)
                  ),
                  DataColumn2(
                      label: const Text('CU Veg', style: TextStyle(fontWeight: FontWeight.bold)),
                      size: ColumnSize.S
                  ),
                  DataColumn2(
                      label: const Text('Gen 1', style: TextStyle(fontWeight: FontWeight.bold)),
                      numeric: true,
                      size: ColumnSize.S,
                      onSort: (columnIndex, ascending) => _sort<num>((d) => d.generative1Visits, columnIndex, ascending)
                  ),
                  DataColumn2(
                      label: const Text('CU G1', style: TextStyle(fontWeight: FontWeight.bold)),
                      size: ColumnSize.S
                  ),
                  DataColumn2(
                      label: const Text('Gen 2', style: TextStyle(fontWeight: FontWeight.bold)),
                      numeric: true,
                      size: ColumnSize.S,
                      onSort: (columnIndex, ascending) => _sort<num>((d) => d.generative2Visits, columnIndex, ascending)
                  ),
                  DataColumn2(
                      label: const Text('CU G2', style: TextStyle(fontWeight: FontWeight.bold)),
                      size: ColumnSize.S
                  ),
                  DataColumn2(
                      label: const Text('Gen 3', style: TextStyle(fontWeight: FontWeight.bold)),
                      numeric: true,
                      size: ColumnSize.S,
                      onSort: (columnIndex, ascending) => _sort<num>((d) => d.generative3Visits, columnIndex, ascending)
                  ),
                  DataColumn2(
                      label: const Text('CU G3', style: TextStyle(fontWeight: FontWeight.bold)),
                      size: ColumnSize.S
                  ),
                  DataColumn2(
                      label: const Text('Pre-H', style: TextStyle(fontWeight: FontWeight.bold)),
                      numeric: true,
                      size: ColumnSize.S,
                      onSort: (columnIndex, ascending) => _sort<num>((d) => d.preHarvestVisits, columnIndex, ascending)
                  ),
                  DataColumn2(
                      label: const Text('CU Pre', style: TextStyle(fontWeight: FontWeight.bold)),
                      size: ColumnSize.S
                  ),
                  DataColumn2(
                      label: const Text('Harv', style: TextStyle(fontWeight: FontWeight.bold)),
                      numeric: true,
                      size: ColumnSize.S,
                      onSort: (columnIndex, ascending) => _sort<num>((d) => d.harvestVisits, columnIndex, ascending)
                  ),
                  DataColumn2(
                      label: const Text('CU Har', style: TextStyle(fontWeight: FontWeight.bold)),
                      size: ColumnSize.S
                  ),
                ],
                source: _CustomVisitDataSource(context, _filteredDisplayData),
                rowsPerPage: _rowsPerPage,
                onRowsPerPageChanged: (value) {
                  setState(() {
                    _rowsPerPage = value ?? PaginatedDataTable.defaultRowsPerPage;
                  });
                },
                sortColumnIndex: _sortColumnIndex,
                sortAscending: _sortAscending,
                headingRowHeight: 50,
                dataRowHeight: 56,
                minWidth: 1200,
                showFirstLastButtons: true,
                empty: Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.info_outline, size: 60, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            _filteredDisplayData.isEmpty ?
                            (_selectedFI != null && _selectedFI!.isNotEmpty ?
                            'No data available for the selected Field Inspector.' :
                            'No visit data available.') :
                            'No visit data available.',
                            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

bool _listEquals<T>(List<T>? a, List<T>? b) {
  if (a == null) return b == null;
  if (b == null || a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

class _CustomVisitDataSource extends DataTableSource {
  final BuildContext context;
  List<VisitData> _data;

  _CustomVisitDataSource(this.context, this._data);

  void updateData(List<VisitData> newData) {
    _data = newData;
    notifyListeners();
  }

  @override
  DataRow? getRow(int index) {
    if (index >= _data.length) return null;
    final data = _data[index];

    // Helper function to determine cell background color based on value
    Color getCellColor(int visits) {
      if (visits == 0) return Colors.red.withAlpha(25);
      if (visits >= 2) return Colors.green.withAlpha(25);
      return Colors.transparent;
    }

    // Helper function for text style based on value
    TextStyle getTextStyle(int visits) {
      if (visits == 0) return const TextStyle(color: Colors.red);
      if (visits >= 2) return const TextStyle(color: Colors.green, fontWeight: FontWeight.bold);
      return const TextStyle();
    }

    return DataRow2.byIndex(
      index: index,
      color: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return Theme.of(context).colorScheme.primary.withAlpha(20);
          }
          if (index % 2 == 0) return Colors.grey.withAlpha(12);
          return null;
        },
      ),
      cells: [
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withAlpha(25),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              data.fieldNumber,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: getCellColor(data.vegetativeVisits),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              data.vegetativeVisits.toString(),
              style: getTextStyle(data.vegetativeVisits),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        DataCell(Text(data.uniformityVeg ?? '-')),
        DataCell(
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: getCellColor(data.generative1Visits),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              data.generative1Visits.toString(),
              style: getTextStyle(data.generative1Visits),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        DataCell(Text(data.uniformityGen1 ?? '-')),
        DataCell(
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: getCellColor(data.generative2Visits),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              data.generative2Visits.toString(),
              style: getTextStyle(data.generative2Visits),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        DataCell(Text(data.uniformityGen2 ?? '-')),
        DataCell(
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: getCellColor(data.generative3Visits),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              data.generative3Visits.toString(),
              style: getTextStyle(data.generative3Visits),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        DataCell(Text(data.uniformityGen3 ?? '-')),
        DataCell(
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: getCellColor(data.preHarvestVisits),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              data.preHarvestVisits.toString(),
              style: getTextStyle(data.preHarvestVisits),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        DataCell(Text(data.uniformityPre ?? '-')),
        DataCell(
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: getCellColor(data.harvestVisits),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              data.harvestVisits.toString(),
              style: getTextStyle(data.harvestVisits),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        DataCell(Text(data.uniformityHar ?? '-')),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => _data.length;

  @override
  int get selectedRowCount => 0;
}