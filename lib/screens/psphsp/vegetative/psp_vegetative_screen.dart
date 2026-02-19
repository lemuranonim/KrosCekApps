// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:ui'; // Penting untuk ImageFilter (Blur)
import 'package:flutter/material.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'package:lottie/lottie.dart';

import '../../services/config_manager.dart';
import '../../services/google_sheets_api.dart';
import 'psp_vegetative_detail_screen.dart';
import 'psp_vegetative_listview_builder.dart';

class PspVegetativeScreen extends StatefulWidget {
  final String spreadsheetId;
  final String region;

  final String? selectedZone;
  final String? selectedFA;

  const PspVegetativeScreen({
    super.key,
    required this.spreadsheetId,
    required this.region,
    this.selectedZone,
    this.selectedFA,
  });

  @override
  PspVegetativeScreenState createState() => PspVegetativeScreenState();
}

class PspVegetativeScreenState extends State<PspVegetativeScreen> {
  late final GoogleSheetsApi _googleSheetsApi;
  final _worksheetTitle = 'Vegetative';

  final List<List<String>> _sheetData = [];
  List<List<String>> _filteredData = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _searchQuery = '';
  Timer? _debounce;
  final TextEditingController _searchController = TextEditingController();

  double _totalEffectiveArea = 0.0;

  // Premium Theme Colors (Selaras dengan Homepage)
  final Color _primaryPurple = Colors.purple.shade800;
  final Color _bgGradientTop = const Color(0xFFF3E5F5); // Purple 50
  final Color _bgGradientBottom = const Color(0xFFFAFAFA); // White

  @override
  void initState() {
    super.initState();
    final sheetId = widget.spreadsheetId.isNotEmpty
        ? widget.spreadsheetId
        : ConfigManager.getSpreadsheetId(widget.region) ?? '';

    _googleSheetsApi = GoogleSheetsApi(sheetId);
    _loadSheetData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String getValue(List<String> row, int index, String defaultValue) {
    if (index < row.length) {
      return row[index].trim();
    }
    return defaultValue;
  }

  Future<void> _loadSheetData({bool refresh = false}) async {
    if (refresh) {
      _sheetData.clear();
      _totalEffectiveArea = 0.0;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _googleSheetsApi.init();
      final data = await _googleSheetsApi.getSpreadsheetDataWithPagination(
          _worksheetTitle,
          1,
          2500
      );

      setState(() {
        _sheetData.addAll(data);
        _isLoading = false;
        _filterData();
      });

    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Gagal memuat data: $e";
      });
    }
  }

  void _filterData() {
    setState(() {
      _filteredData = _sheetData.where((row) {
        final zoneData = getValue(row, 17, '').toLowerCase();
        final faData = getValue(row, 18, '').toLowerCase();

        bool matchesZone = true;
        if (widget.selectedZone != null && widget.selectedZone!.isNotEmpty) {
          matchesZone = zoneData == widget.selectedZone!.toLowerCase();
        }

        bool matchesFA = true;
        if (widget.selectedFA != null && widget.selectedFA!.isNotEmpty) {
          matchesFA = faData == widget.selectedFA!.toLowerCase();
        }

        final fieldNumber = getValue(row, 2, '').toLowerCase();
        final farmerName = getValue(row, 4, '').toLowerCase();

        bool matchesSearch = true;
        if (_searchQuery.isNotEmpty) {
          matchesSearch = fieldNumber.contains(_searchQuery) ||
              farmerName.contains(_searchQuery);
        }

        return matchesZone && matchesFA && matchesSearch;
      }).toList();

      _totalEffectiveArea = _filteredData.fold(0.0, (sum, row) {
        final areaStr = getValue(row, 10, '0').replaceAll(',', '.');
        return sum + (double.tryParse(areaStr) ?? 0.0);
      });
    });
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = query.toLowerCase();
      });
      _filterData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // Agar background sampai ke atas
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(0), // Kita buat Custom Header, jadi AppBar 0
        child: AppBar(elevation: 0, backgroundColor: Colors.transparent),
      ),
      body: Stack(
        children: [
          // 1. Background Gradient (Subtle)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_bgGradientTop, _bgGradientBottom],
                stops: const [0.0, 0.3],
              ),
            ),
          ),

          // 2. Decorative Blob (Top Right)
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.purple.shade100.withOpacity(0.4),
                boxShadow: [
                  BoxShadow(color: Colors.purple.shade200.withOpacity(0.3), blurRadius: 60, spreadRadius: 10),
                ],
              ),
            ),
          ),

          // 3. Main Content
          Column(
            children: [
              // --- CUSTOM HEADER & SEARCH ---
              _buildCustomHeader(context),

              // --- LIST CONTENT ---
              Expanded(
                child: LiquidPullToRefresh(
                  onRefresh: () async => await _loadSheetData(refresh: true),
                  color: _primaryPurple,
                  backgroundColor: Colors.white,
                  showChildOpacityTransition: false,
                  springAnimationDurationInMilliseconds: 500,
                  child: _isLoading
                      ? Center(child: Lottie.asset('assets/loading.json', width: 150))
                      : _errorMessage != null
                      ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline_rounded, size: 48, color: Colors.red.shade300),
                        const SizedBox(height: 16),
                        Text(_errorMessage!, style: TextStyle(color: Colors.grey.shade600)),
                      ],
                    ),
                  )
                      : PspVegetativeListViewBuilder(
                    filteredData: _filteredData,
                    selectedRegion: widget.region,
                    onItemTap: (fieldNumber) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PspVegetativeDetailScreen(
                            fieldNumber: fieldNumber,
                            region: widget.region,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),

          // 4. FLOATING SUMMARY DOCK (Bottom)
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: _buildFloatingSummaryDock(),
          ),
        ],
      ),
    );
  }

  // --- WIDGET: Custom Header ---
  Widget _buildCustomHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20,
        right: 20,
        bottom: 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.5), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.shade900.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row: Back Button & Title
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Icon(Icons.arrow_back_ios_new_rounded, color: _primaryPurple, size: 20),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Vegetative List",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          "Zone: ${widget.selectedZone ?? '-'} • FA: ${widget.selectedFA ?? '-'}",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Search Bar (Glassmorphism Capsule)
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'Search Field No / Farmer...',
                    hintStyle: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.normal),
                    prefixIcon: Icon(Icons.search_rounded, color: _primaryPurple),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear_rounded, color: Colors.grey, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET: Floating Summary Dock ---
  Widget _buildFloatingSummaryDock() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _primaryPurple.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _primaryPurple.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Count Info
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.grid_view_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_filteredData.length} Fields',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Found',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              Container(height: 30, width: 1, color: Colors.white.withOpacity(0.2)),

              // Area Info
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${_totalEffectiveArea.toStringAsFixed(2)} Ha',
                        style: const TextStyle(
                          color: Color(0xFFFFC400), // Amber Premium
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Total Area',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC400).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.landscape_rounded, color: Color(0xFFFFC400), size: 18),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}