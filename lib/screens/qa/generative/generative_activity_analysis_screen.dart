import 'package:flutter/material.dart';
import 'analysis_dashboard_tab.dart';
import 'analysis_heatmap_tab.dart';

// Define app theme constants
class AppTheme {
  // Primary colors
  static const Color primaryDark = Color(0xFF1B5E20);
  static const Color primary = Color(0xFF2E7D32);
  static const Color primaryLight = Color(0xFF4CAF50);

  // Accent colors
  static const Color accent = Color(0xFF1976D2);
  static const Color accentLight = Color(0xFF42A5F5);

  // Status colors
  static const Color success = Color(0xFF388E3C);
  static const Color warning = Color(0xFFFFA000);
  static const Color error = Color(0xFFD32F2F);
  static const Color info = Color(0xFF0288D1);

  // Neutral colors
  static const Color textDark = Color(0xFF212121);
  static const Color textMedium = Color(0xFF757575);
  static const Color textLight = Color(0xFFBDBDBD);
  static const Color background = Color(0xFFF5F5F5);

  // Text styles
  static const TextStyle heading1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: textDark,
    letterSpacing: 0.5,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: textDark,
    letterSpacing: 0.25,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textDark,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: textMedium,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    color: textDark,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: textMedium,
  );

  // Card decoration
  static BoxDecoration cardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withAlpha(12),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

class GenerativeActivityAnalysisScreen extends StatefulWidget {
  final Map<String, int> activityCounts;
  final Map<String, List<DateTime>> activityTimestamps;
  final List<List<String>> generativeData;
  final List<List<String>> vegetativeData;
  final String? selectedRegion;

  const GenerativeActivityAnalysisScreen({
    super.key,
    required this.activityCounts,
    required this.activityTimestamps,
    required this.generativeData,
    required this.vegetativeData,
    this.selectedRegion,
  });

  @override
  State<GenerativeActivityAnalysisScreen> createState() => _GenerativeActivityAnalysisScreenState();
}

class _GenerativeActivityAnalysisScreenState extends State<GenerativeActivityAnalysisScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  // Audit status constants
  static const String _auditStatusSampun = "Sampun";
  static const String _auditStatusDerengJangkep = "Dereng Jangkep";
  static const String _auditStatusDerengBlas = "Dereng Blas";

  // Filters
  String _searchQuery = '';

  // Sorting
  final String _sortColumn = 'activityCount';
  final bool _sortAscending = false;

  // VARIABEL BARU UNTUK FILTER STATUS AUDIT
  Set<String> _selectedAuditStatuses = {
    _auditStatusSampun,
    _auditStatusDerengJangkep,
    _auditStatusDerengBlas,
  };

  // Count variables for audit status
  int sampunCount = 0;
  int derengJangkepCount = 0;
  int derengBlasCount = 0;

  // Activity count variables
  int sampunWithActivity = 0;
  int derengJangkepWithActivity = 0;
  int derengBlasWithActivity = 0;

  // Area variables
  double sampunArea = 0.0;
  double derengJangkepArea = 0.0;
  double derengBlasArea = 0.0;

  // Calculated statistics
  int _fieldsWithActivity = 0;
  Map<int, int> _activityDistribution = {};

  // Variabel baru untuk analisis ketersediaan
  double ketersediaanAreaA = 0.0;
  double ketersediaanAreaB = 0.0;
  double ketersediaanAreaC = 0.0;
  double ketersediaanAreaD = 0.0;
  double ketersediaanAreaE = 0.0;

  // Variabel baru untuk analisis efektivitas
  double efektivitasAreaEfektif = 0.0;
  double efektivitasAreaTidakEfektif = 0.0;

  // Variabel untuk filter "Week of Flowering"
  Set<String> _selectedWeeks = {};
  List<String> _availableWeeks = [];

  List<String> _availableGrowers = [];
  Set<String> _selectedGrowers = {};

  List<String> _availableCoordinators = [];
  Map<String, String> _fieldToCoordinator = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final weekSet = <String>{};
    for (var row in widget.generativeData) {
      final week = getValue(row, 28, "").trim();
      if (week.isNotEmpty) {
        weekSet.add(week);
      }
    }
    _availableWeeks = weekSet.toList()..sort();
    _selectedWeeks = Set<String>.from(_availableWeeks);

    final growerSet = <String>{};
    for (var row in widget.generativeData) {
      // Mengambil data dari kolom ke-4 (indeks) untuk Grower
      final grower = getValue(row, 4, "").trim();
      if (grower.isNotEmpty && grower != "0") {
        growerSet.add(grower);
      }
    }
    _availableGrowers = growerSet.toList()..sort();
    _selectedGrowers = Set<String>.from(_availableGrowers);

    // BARU: Buat Map untuk mapping Field Number ke Coordinator
    final Map<String, String> fieldToCoordinator = {};

    debugPrint('=== DEBUG CO-DET MAPPING ===');
    debugPrint('Generative rows: ${widget.generativeData.length}');
    debugPrint('Vegetative rows: ${widget.vegetativeData.length}');

    // Mapping dari vegetativeData: Lewati baris pertama (header) dengan .skip(1)
    for (var row in widget.vegetativeData.skip(1)) { // <-- PERUBAHAN KUNCI DI SINI
      final fieldNumber = getValue(row, 2, "").trim(); // Field Number di kolom C
      final coordinator = getValue(row, 32, "").trim().toLowerCase(); // Coordinator di kolom AG

      // Karena header sudah dilewati, pengecekan "coordinator detasseling" bisa dihapus
      if (fieldNumber.isNotEmpty &&
          coordinator.isNotEmpty &&
          coordinator != "0") {
        fieldToCoordinator[fieldNumber] = coordinator;
      }
    }

    debugPrint('Total field-to-coordinator mappings: ${fieldToCoordinator.length}');

    // Ambil unique coordinators dari mapping
    final coordinatorSet = fieldToCoordinator.values.toSet();
    _availableCoordinators = coordinatorSet.toList()..sort();

    debugPrint('=== RESULT ===');
    debugPrint('Total unique coordinators: ${_availableCoordinators.length}');
    if (_availableCoordinators.isNotEmpty) {
      debugPrint('Coordinators: $_availableCoordinators');
      debugPrint('Sample mappings:');
      int count = 0;
      for (var entry in fieldToCoordinator.entries) {
        if (count < 5) {
          debugPrint('  ${entry.key} → ${entry.value}');
          count++;
        }
      }
    } else {
      debugPrint('WARNING: No coordinators found!');
    }
    debugPrint('==================');

    // SIMPAN MAPPING SEBAGAI VARIABEL INSTANCE
    _fieldToCoordinator = fieldToCoordinator;

    // Simulate loading delay
    Future.delayed(const Duration(milliseconds: 500), () {
      _calculateStatistics();
      setState(() {
        _isLoading = false;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String getKetersediaanStatus(List<String> row) {
    // Kolom AK adalah indeks ke-36 (A=0, B=1, ..., AK=36)
    // Sesuaikan indeks ini jika posisi kolom berbeda
    final value = getValue(row, 36, "").trim().toUpperCase();
    return value; // Seharusnya mengembalikan 'A', 'B', 'C', 'D', atau 'E'
  }

  String getEffectivenessStatus(List<String> row) {
    // Kolom AN adalah indeks ke-39 (A=0, B=1, ..., AN=39)
    // Sesuaikan indeks ini jika posisi kolom berbeda
    final value = getValue(row, 39, "").trim().toUpperCase();
    if (value == 'A') {
      return 'Efektif';
    } else if (value == 'B') {
      return 'Tidak Efektif';
    }
    return 'N/A'; // Default jika data tidak A atau B
  }

  String getAuditStatus(List<String> row) {
    // Get values from columns BT and BU (assuming these are indices 71 and 72)
    // Note: Adjust these indices based on the actual position of columns BT and BU
    final btValue = getValue(row, 72, "").trim().toLowerCase();
    final buValue = getValue(row, 73, "").trim().toLowerCase();

    // Check for "Audited" status in both columns
    final isBtAudited = btValue == "audited";
    final isBuAudited = buValue == "audited";

    if (isBtAudited && isBuAudited) {
      // Both columns show "Audited"
      return _auditStatusSampun;
    } else if (isBtAudited || isBuAudited) {
      // Only one column shows "Audited"
      return _auditStatusDerengJangkep;
    } else {
      // Neither column shows "Audited"
      return _auditStatusDerengBlas;
    }
  }

  Color getAuditStatusColor(String status) {
    switch (status) {
      case _auditStatusSampun:
        return AppTheme.success;
      case _auditStatusDerengJangkep:
        return AppTheme.warning;
      case _auditStatusDerengBlas:
        return AppTheme.error;
      default:
        return AppTheme.error;
    }
  }

  IconData getAuditStatusIcon(String status) {
    switch (status) {
      case _auditStatusSampun:
        return Icons.check_circle;
      case _auditStatusDerengJangkep:
        return Icons.warning;
      case _auditStatusDerengBlas:
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  void _calculateStatistics() {
    // Basic counts
    _fieldsWithActivity = widget.activityCounts.keys.length;

    // Activity distribution
    _activityDistribution = {};
    for (var count in widget.activityCounts.values) {
      _activityDistribution[count] = (_activityDistribution[count] ?? 0) + 1;
    }

    sampunCount = 0;
    derengJangkepCount = 0;
    derengBlasCount = 0;

    sampunWithActivity = 0;
    derengJangkepWithActivity = 0;
    derengBlasWithActivity = 0;

    sampunArea = 0.0;
    derengJangkepArea = 0.0;
    derengBlasArea = 0.0;

    // Reset variabel baru kita
    ketersediaanAreaA = 0.0;
    ketersediaanAreaB = 0.0;
    ketersediaanAreaC = 0.0;
    ketersediaanAreaD = 0.0;
    ketersediaanAreaE = 0.0;

    efektivitasAreaEfektif = 0.0;
    efektivitasAreaTidakEfektif = 0.0;

    // Gunakan data yang sudah difilter untuk perhitungan
    final currentFilteredData = getFilteredData();

    for (var row in currentFilteredData) {
      final fieldNumber = getValue(row, 2, "Unknown");
      final auditStatus = getAuditStatus(row);
      final hasActivity = widget.activityCounts.containsKey(fieldNumber);
      final effectiveAreaStr = getValue(row, 8, "0").replaceAll(',', '.');
      final effectiveArea = double.tryParse(effectiveAreaStr) ?? 0.0;

      if (auditStatus == _auditStatusSampun) {
        sampunCount++;
        sampunArea += effectiveArea;
        if (hasActivity) sampunWithActivity++;
      } else if (auditStatus == _auditStatusDerengJangkep) {
        derengJangkepCount++;
        derengJangkepArea += effectiveArea;
        if (hasActivity) derengJangkepWithActivity++;
      } else {
        derengBlasCount++;
        derengBlasArea += effectiveArea;
        if (hasActivity) derengBlasWithActivity++;
      }

      // Kalkulasi Analisis Ketersediaan
      final ketersediaanStatus = getKetersediaanStatus(row);
      switch (ketersediaanStatus) {
        case 'A':
          ketersediaanAreaA += effectiveArea;
          break;
        case 'B':
          ketersediaanAreaB += effectiveArea;
          break;
        case 'C':
          ketersediaanAreaC += effectiveArea;
          break;
        case 'D':
          ketersediaanAreaD += effectiveArea;
          break;
        case 'E':
          ketersediaanAreaE += effectiveArea;
          break;
      }

      // Kalkulasi Analisis Efektivitas
      final effectivenessStatus = getEffectivenessStatus(row);
      if (effectivenessStatus == 'Efektif') {
        efektivitasAreaEfektif += effectiveArea;
      } else if (effectivenessStatus == 'Tidak Efektif') {
        efektivitasAreaTidakEfektif += effectiveArea;
      }
    }
  }

  List<List<String>> getFilteredData() {
    return widget.generativeData.where((row) {
      final fieldNumber = getValue(row, 2, "Unknown").toLowerCase();
      final farmerName = getValue(row, 3, "Unknown").toLowerCase();
      final hybrid = getValue(row, 5, "Unknown").toLowerCase();
      final auditStatus = getAuditStatus(row);
      final weekValue = getValue(row, 28, "").trim();
      final growerValue = getValue(row, 4, "").trim();

      // Apply search filter
      bool matchesSearch = _searchQuery.isEmpty ||
          fieldNumber.contains(_searchQuery.toLowerCase()) ||
          farmerName.contains(_searchQuery.toLowerCase()) ||
          getValue(row, 4, "").contains(_searchQuery.toLowerCase()) ||
          hybrid.contains(_searchQuery.toLowerCase());

      // Apply audit status filter
      bool matchesAuditStatus = _selectedAuditStatuses.contains(auditStatus);
      bool matchesWeek = _selectedWeeks.contains(weekValue);
      bool matchesGrower = _selectedGrowers.contains(growerValue);

      return matchesSearch && matchesAuditStatus && matchesWeek && matchesGrower;
    }).toList();
  }

  List<List<String>> getSortedData(List<List<String>> filteredData) {
    final sortedData = List<List<String>>.from(filteredData);

    switch (_sortColumn) {
      case 'fieldNumber':
        sortedData.sort((a, b) {
          final fieldNumberA = getValue(a, 2, "");
          final fieldNumberB = getValue(b, 2, "");
          return _sortAscending
              ? fieldNumberA.compareTo(fieldNumberB)
              : fieldNumberB.compareTo(fieldNumberA);
        });
        break;
      case 'activityCount':
        sortedData.sort((a, b) {
          final fieldNumberA = getValue(a, 2, "");
          final fieldNumberB = getValue(b, 2, "");
          final countA = widget.activityCounts[fieldNumberA] ?? 0;
          final countB = widget.activityCounts[fieldNumberB] ?? 0;
          return _sortAscending
              ? countA.compareTo(countB)
              : countB.compareTo(countA);
        });
        break;
      case 'auditStatus':
        sortedData.sort((a, b) {
          final statusA = getAuditStatus(a);
          final statusB = getAuditStatus(b);
          return _sortAscending
              ? statusA.compareTo(statusB)
              : statusB.compareTo(statusA);
        });
        break;
      case 'dap':
        sortedData.sort((a, b) {
          final dapA = calculateDAP(a);
          final dapB = calculateDAP(b);
          return _sortAscending
              ? dapA.compareTo(dapB)
              : dapB.compareTo(dapA);
        });
        break;
      case 'area':
        sortedData.sort((a, b) {
          final areaStrA = getValue(a, 8, "0").replaceAll(',', '.');
          final areaStrB = getValue(b, 8, "0").replaceAll(',', '.');
          final areaA = double.tryParse(areaStrA) ?? 0.0;
          final areaB = double.tryParse(areaStrB) ?? 0.0;
          return _sortAscending
              ? areaA.compareTo(areaB)
              : areaB.compareTo(areaA);
        });
        break;
      case 'farmer':
        sortedData.sort((a, b) {
          final farmerA = getValue(a, 3, "Unknown");
          final farmerB = getValue(b, 3, "Unknown");
          return _sortAscending
              ? farmerA.compareTo(farmerB)
              : farmerB.compareTo(farmerA);
        });
        break;
    }

    return sortedData;
  }

  @override
  Widget build(BuildContext context) {
    // Panggil _calculateStatistics di sini agar selalu update saat filter berubah
    // Panggilan ini akan terjadi setiap kali setState dipanggil
    if (!_isLoading) {
      _calculateStatistics();
    }

    final filteredData = getFilteredData();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Analysis',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.primaryDark, AppTheme.primary],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(25),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 2,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withAlpha(178),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 13,
          ),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
            Tab(icon: Icon(Icons.grid_on), text: 'Heatmap'),
          ],
        ),
        actions: [
          // Filter Dropdown untuk "Coordinator Detaseling"
          IconButton(
            icon: const Icon(Icons.supervisor_account),
            color: Colors.white,
            tooltip: 'Filter Grower',
            onPressed: () {
              _showGrowerFilterDialog();
            },
          ),

          // Filter Dropdown Premium untuk "Week of Flowering"
          IconButton(
            icon: const Icon(Icons.calendar_today),
            color: Colors.white,
            tooltip: 'Filter Week of Flowering',
            onPressed: () {
              _showWeekFilterDialog(); // Panggil dialog filter minggu
            },
          ),

          // Filter button
          IconButton(
            icon: const Icon(Icons.filter_list),
            color: Colors.white,
            tooltip: 'Filter Status Audit',
            onPressed: () {
              _showFilterDialog(); // Panggil dialog baru kita
            },
          ),

          // Search button
          IconButton(
            icon: const Icon(Icons.search),
            color: Colors.white,
            tooltip: 'Cari Lahan',
            onPressed: () {
              _showSearchDialog();
            },
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingView()
          : TabBarView(
        controller: _tabController,
        children: [
          // Dashboard Tab
          AnalysisDashboardTab(
            filteredData: filteredData,
            activityCounts: widget.activityCounts,
            activityTimestamps: widget.activityTimestamps,
            sampunCount: sampunCount,
            derengJangkepCount: derengJangkepCount,
            derengBlasCount: derengBlasCount,
            sampunWithActivity: sampunWithActivity,
            derengJangkepWithActivity: derengJangkepWithActivity,
            derengBlasWithActivity: derengBlasWithActivity,
            sampunArea: sampunArea,
            derengJangkepArea: derengJangkepArea,
            derengBlasArea: derengBlasArea,
            fieldsWithActivity: _fieldsWithActivity,
            searchQuery: _searchQuery,
            tabController: _tabController,
            selectedRegion: widget.selectedRegion,
            getAuditStatus: getAuditStatus,
            getAuditStatusColor: getAuditStatusColor,
            getAuditStatusIcon: getAuditStatusIcon,
            // Properti baru untuk analisis
            ketersediaanAreaA: ketersediaanAreaA,
            ketersediaanAreaB: ketersediaanAreaB,
            ketersediaanAreaC: ketersediaanAreaC,
            ketersediaanAreaD: ketersediaanAreaD,
            ketersediaanAreaE: ketersediaanAreaE,
            efektivitasAreaEfektif: efektivitasAreaEfektif,
            efektivitasAreaTidakEfektif: efektivitasAreaTidakEfektif,
            availableGrowers: _availableGrowers,
            availableCoordinators: _availableCoordinators,
            fieldToCoordinator: _fieldToCoordinator,
            getKetersediaanStatus: getKetersediaanStatus,
            getEffectivenessStatus: getEffectivenessStatus,
          ),

          // Heatmap Tab
          AnalysisHeatmapTab(
            filteredData: filteredData,
            activityCounts: widget.activityCounts,
            selectedRegion: widget.selectedRegion,
            getAuditStatus: getAuditStatus,
            getAuditStatusColor: getAuditStatusColor,
          ),
        ],
      ),
    );
  }

  void _showSearchDialog() {
    // Gunakan TextEditingController untuk mengelola input teks pencarian
    // Initial value diambil dari _searchQuery saat ini
    final TextEditingController searchController = TextEditingController(text: _searchQuery);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Sangat penting agar keyboard tidak menutupi input
      backgroundColor: Colors.transparent, // Untuk sudut melengkung
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom), // Menyesuaikan dengan keyboard
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).canvasColor, // Warna latar belakang kartu
              borderRadius: const BorderRadius.vertical(top: Radius.circular(25.0)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16), // Padding atas, kiri, kanan, bawah
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min, // Sesuaikan tinggi dengan konten
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Judul Pencarian
                  Text(
                    'Cari Lahan',
                    style: AppTheme.heading2.copyWith(fontSize: 22),
                  ),
                  const SizedBox(height: 16),

                  // Deskripsi
                  const Text(
                    'Cari berdasarkan No. Lahan, Nama Petani, Nama Penanam, atau Hibrida:',
                    style: TextStyle(fontSize: 14, color: AppTheme.textMedium),
                  ),
                  const SizedBox(height: 16),

                  // TextField untuk Input Pencarian
                  TextField(
                    controller: searchController,
                    autofocus: true, // Otomatis fokus saat dialog muncul
                    decoration: InputDecoration(
                      hintText: 'Masukkan kata kunci...',
                      prefixIcon: const Icon(Icons.search, color: AppTheme.primary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none, // Hilangkan border default
                      ),
                      filled: true,
                      fillColor: AppTheme.primary.withAlpha(20), // Warna latar belakang input
                      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    ),
                    onSubmitted: (value) {
                      // Ketika Enter ditekan, terapkan pencarian dan tutup dialog
                      setState(() {
                        _searchQuery = value;
                      });
                      Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(height: 24),

                  // Tombol Aksi (Batal & Cari)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            // Batalkan pencarian dan tutup dialog
                            Navigator.of(context).pop();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.textMedium,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('BATAL', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            // Terapkan pencarian dan tutup dialog
                            setState(() {
                              _searchQuery = searchController.text;
                            });
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Text('CARI', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showGrowerFilterDialog() {
    final tempSelectedGrowers = Set<String>.from(_selectedGrowers);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).canvasColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(25.0)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filter Grower', // <-- Diubah
                      style: AppTheme.heading2.copyWith(fontSize: 22),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 10.0,
                          runSpacing: 10.0,
                          children: _availableGrowers.map((grower) { // <-- Diubah
                            return _buildFilterChip(
                              label: grower, // <-- Diubah
                              status: grower, // <-- Diubah
                              isSelected: tempSelectedGrowers.contains(grower), // <-- Diubah
                              color: AppTheme.info,
                              onSelected: (selected) {
                                setDialogState(() {
                                  if (selected) {
                                    tempSelectedGrowers.add(grower); // <-- Diubah
                                  } else {
                                    tempSelectedGrowers.remove(grower); // <-- Diubah
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        TextButton(
                          onPressed: () {
                            setDialogState(() {
                              tempSelectedGrowers.addAll(_availableGrowers); // <-- Diubah
                            });
                          },
                          child: const Text('Pilih Semua'),
                        ),
                        TextButton(
                          onPressed: () {
                            setDialogState(() {
                              tempSelectedGrowers.clear(); // <-- Diubah
                            });
                          },
                          child: const Text('Hapus Semua'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(context).pop(); // Batal, tutup dialog
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.textMedium,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('BATAL', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              // Terapkan perubahan ke state utama
                              setState(() {
                                _selectedGrowers = tempSelectedGrowers;
                              });
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary, // Warna utama aplikasi
                              foregroundColor: Colors.white, // Warna teks
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0, // Tanpa shadow untuk tampilan flat modern
                            ),
                            child: const Text('TERAPKAN FILTER', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showFilterDialog() {
    final tempSelectedStatuses = Set<String>.from(_selectedAuditStatuses);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Penting agar bisa scroll jika kontennya panjang
      backgroundColor: Colors.transparent, // Untuk sudut melengkung
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              // Gaya kontainer bottom sheet
              decoration: BoxDecoration(
                color: Theme.of(context).canvasColor, // Warna latar belakang kartu
                borderRadius: const BorderRadius.vertical(top: Radius.circular(25.0)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8), // Padding atas, kiri, kanan, bawah
              child: SafeArea( // Pastikan konten tidak terhalang notch/gesture bar
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Sesuaikan tinggi dengan konten
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Judul Dialog
                    Text(
                      'Filter Status Audit',
                      style: AppTheme.heading2.copyWith(fontSize: 22), // Lebih besar dan bold
                    ),
                    const SizedBox(height: 16),

                    // Deskripsi (opsional, bisa dihapus jika tidak diperlukan)
                    const Text(
                      'Pilih status audit yang ingin Anda tampilkan:',
                      style: TextStyle(fontSize: 14, color: AppTheme.textMedium),
                    ),
                    const SizedBox(height: 16),

                    // Opsi Filter menggunakan Wrap dan FilterChip
                    Wrap(
                      spacing: 10.0, // Jarak antar chip
                      runSpacing: 10.0, // Jarak antar baris chip
                      children: [
                        _buildFilterChip(
                          label: 'Sampun',
                          status: _auditStatusSampun,
                          isSelected: tempSelectedStatuses.contains(_auditStatusSampun),
                          color: AppTheme.success,
                          onSelected: (selected) {
                            setDialogState(() {
                              if (selected) {
                                tempSelectedStatuses.add(_auditStatusSampun);
                              } else {
                                tempSelectedStatuses.remove(_auditStatusSampun);
                              }
                            });
                          },
                        ),
                        _buildFilterChip(
                          label: 'Dereng Jangkep',
                          status: _auditStatusDerengJangkep,
                          isSelected: tempSelectedStatuses.contains(_auditStatusDerengJangkep),
                          color: AppTheme.warning,
                          onSelected: (selected) {
                            setDialogState(() {
                              if (selected) {
                                tempSelectedStatuses.add(_auditStatusDerengJangkep);
                              } else {
                                tempSelectedStatuses.remove(_auditStatusDerengJangkep);
                              }
                            });
                          },
                        ),
                        _buildFilterChip(
                          label: 'Dereng Blas',
                          status: _auditStatusDerengBlas,
                          isSelected: tempSelectedStatuses.contains(_auditStatusDerengBlas),
                          color: AppTheme.error,
                          onSelected: (selected) {
                            setDialogState(() {
                              if (selected) {
                                tempSelectedStatuses.add(_auditStatusDerengBlas);
                              } else {
                                tempSelectedStatuses.remove(_auditStatusDerengBlas);
                              }
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Tombol Aksi (Pilih Semua / Hapus Semua)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        TextButton(
                          onPressed: () {
                            setDialogState(() {
                              tempSelectedStatuses.addAll([_auditStatusSampun, _auditStatusDerengJangkep, _auditStatusDerengBlas]);
                            });
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.accent, // Warna teks
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Pilih Semua', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        TextButton(
                          onPressed: () {
                            setDialogState(() {
                              tempSelectedStatuses.clear();
                            });
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.error, // Warna teks
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Hapus Semua', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24), // Spasi sebelum tombol utama

                    // Tombol Terapkan dan Batal (di bagian bawah sheet)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(context).pop(); // Batal, tutup dialog
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.textMedium,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('BATAL', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              // Terapkan perubahan ke state utama
                              setState(() {
                                _selectedAuditStatuses = tempSelectedStatuses;
                              });
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary, // Warna utama aplikasi
                              foregroundColor: Colors.white, // Warna teks
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0, // Tanpa shadow untuk tampilan flat modern
                            ),
                            child: const Text('TERAPKAN FILTER', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0 ? 0 : 8), // Menyesuaikan dengan keyboard
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Tambahkan helper widget untuk FilterChip agar kode lebih rapi
  Widget _buildFilterChip({
    required String label,
    required String status,
    required bool isSelected,
    required Color color,
    required Function(bool) onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppTheme.textDark,
        fontWeight: FontWeight.w600,
      ),
      checkmarkColor: Colors.white,
      selectedColor: color,
      backgroundColor: color.withAlpha(25), // Latar belakang samar saat tidak dipilih
      side: BorderSide(color: isSelected ? color : AppTheme.textMedium.withAlpha(127)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppTheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Loading analysis data...',
            style: AppTheme.subtitle,
          ),
        ],
      ),
    );
  }

  void _showWeekFilterDialog() {
    final tempSelectedWeeks = Set<String>.from(_selectedWeeks);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).canvasColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(25.0)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filter Week of Flowering',
                      style: AppTheme.heading2.copyWith(fontSize: 22),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Pilih satu atau beberapa minggu untuk ditampilkan:',
                      style: TextStyle(fontSize: 14, color: AppTheme.textMedium),
                    ),
                    const SizedBox(height: 16),

                    // Gunakan SingleChildScrollView jika daftar minggu sangat panjang
                    SizedBox(
                      height: 150, // Batasi tinggi area chip agar bisa di-scroll
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 10.0,
                          runSpacing: 10.0,
                          children: _availableWeeks.map((week) {
                            return _buildFilterChip( // Kita gunakan lagi helper yang sama!
                              label: week,
                              status: week,
                              isSelected: tempSelectedWeeks.contains(week),
                              color: AppTheme.accent, // Gunakan warna aksen
                              onSelected: (selected) {
                                setDialogState(() {
                                  if (selected) {
                                    tempSelectedWeeks.add(week);
                                  } else {
                                    tempSelectedWeeks.remove(week);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        TextButton(
                          onPressed: () {
                            setDialogState(() {
                              tempSelectedWeeks.addAll(_availableWeeks);
                            });
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.accent,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Pilih Semua', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        TextButton(
                          onPressed: () {
                            setDialogState(() {
                              tempSelectedWeeks.clear();
                            });
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.error,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Hapus Semua', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('BATAL', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _selectedWeeks = tempSelectedWeeks;
                              });
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: const Text('TERAPKAN FILTER', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0 ? 0 : 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Utility functions
  static String getValue(List<String> row, int index, String defaultValue) {
    if (row.isEmpty || index >= row.length) return defaultValue;
    return row[index];
  }

  static int calculateDAP(List<String> row) {
    try {
      final plantingDate = getValue(row, 9, ''); // Get planting date from column 9
      if (plantingDate.isEmpty) return 0;

      // Try to parse as Excel date number
      final parsedNumber = double.tryParse(plantingDate);
      if (parsedNumber != null) {
        final date = DateTime(1899, 12, 30).add(Duration(days: parsedNumber.toInt()));
        final today = DateTime.now();
        return today.difference(date).inDays;
      } else {
        // Try to parse as formatted date
        try {
          final parts = plantingDate.split('/');
          if (parts.length == 3) {
            final day = int.tryParse(parts[0]) ?? 1;
            final month = int.tryParse(parts[1]) ?? 1;
            final year = int.tryParse(parts[2]) ?? DateTime.now().year;

            final date = DateTime(year, month, day);
            final today = DateTime.now();
            return today.difference(date).inDays;
          }
        } catch (e) {
          // Ignore parsing errors
        }
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }
}