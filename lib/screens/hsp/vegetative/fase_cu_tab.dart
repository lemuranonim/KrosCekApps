import 'package:flutter/material.dart';
import 'vegetative_detail_screen.dart';
import 'app_theme.dart';
import 'utils.dart';

class FaseCuTab extends StatelessWidget {
  final List<List<String>> filteredData;
  final Map<String, int> activityCounts;
  final String? selectedRegion;

  const FaseCuTab({
    super.key,
    required this.filteredData,
    required this.activityCounts,
    required this.selectedRegion,
  });

  bool checkActivity(String fieldNumber, Map<String, int> activityCounts) {
    // Cek apakah fieldNumber memiliki aktivitas di semua fase
    return activityCounts.containsKey(fieldNumber) && activityCounts[fieldNumber]! > 0;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.grid_on, color: AppTheme.accent),
                        const SizedBox(width: 8),
                        const Text(
                          'Fase CU',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Σ ${filteredData.length} lahan',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textMedium,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Legend
                // Legend
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    children: [
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          _buildLegendItem(Colors.grey.shade300, 'Belum'),
                          _buildLegendItem(AppTheme.success, 'Sudah'),
                          _buildLegendItem(AppTheme.warning, 'Proses'),
                          _buildLegendItem(AppTheme.error, 'Terlambat'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Kolom Veg menampilkan jumlah aktivitas Vegetative',
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: AppTheme.textMedium,
                        ),
                      ),
                    ],
                  ),
                ),

                // Data Table
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 12,
                    headingRowHeight: 48,
                    headingRowColor: WidgetStateProperty.all(AppTheme.primary.withAlpha(25)),
                    headingTextStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                      fontSize: 12,
                    ),
                    dataTextStyle: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textDark,
                    ),
                    border: TableBorder.all(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                    columns: const [
                      DataColumn(
                        label: SizedBox(
                          width: 80,
                          child: Text(
                            'Field Number',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                      DataColumn(
                        label: SizedBox(
                          width: 50,
                          child: Text(
                            'Veg',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                      DataColumn(
                        label: SizedBox(
                          width: 50,
                          child: Text(
                            'CU (1)',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                      DataColumn(
                        label: SizedBox(
                          width: 50,
                          child: Text(
                            'Gen (1)',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                      DataColumn(
                        label: SizedBox(
                          width: 50,
                          child: Text(
                            'CU (2)',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                      DataColumn(
                        label: SizedBox(
                          width: 50,
                          child: Text(
                            'Gen (2)',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                      DataColumn(
                        label: SizedBox(
                          width: 50,
                          child: Text(
                            'CU (3)',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                      DataColumn(
                        label: SizedBox(
                          width: 50,
                          child: Text(
                            'Gen (3)',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                      DataColumn(
                        label: SizedBox(
                          width: 50,
                          child: Text(
                            'CU (4)',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                      DataColumn(
                        label: SizedBox(
                          width: 40,
                          child: Text(
                            'H',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                    ],
                    rows: filteredData.map((row) {
                      final fieldNumber = getValue(row, 2, "");
                      final dap = calculateDAP(row);

                      return DataRow(
                        cells: [
                          DataCell(
                            InkWell(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => VegetativeDetailScreen(
                                      fieldNumber: fieldNumber,
                                      region: selectedRegion ?? 'Unknown Region',
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                width: 80,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  fieldNumber,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.accent,
                                    fontSize: 11,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                          // Kirimkan data aktivitas ke fungsi _buildPhaseCell
                          DataCell(_buildPhaseCell('Veg', dap, 0, 30, row, activityCounts)),
                          DataCell(_buildPhaseCell('CU1', dap, 31, 45, row, activityCounts)),
                          DataCell(_buildPhaseCell('Gen1', dap, 46, 60, row, activityCounts)),
                          DataCell(_buildPhaseCell('CU2', dap, 61, 75, row, activityCounts)),
                          DataCell(_buildPhaseCell('Gen2', dap, 76, 90, row, activityCounts)),
                          DataCell(_buildPhaseCell('CU3', dap, 91, 105, row, activityCounts)),
                          DataCell(_buildPhaseCell('Gen3', dap, 106, 120, row, activityCounts)),
                          DataCell(_buildPhaseCell('CU4', dap, 121, 135, row, activityCounts)),
                          DataCell(_buildPhaseCell('H', dap, 136, 150, row, activityCounts)),
                        ],
                      );
                    }).toList(),
                  ),
                ),

                if (filteredData.length > 50)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Center(
                      child: Text(
                        'Menampilkan ${filteredData.length} lahan',
                        style: const TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: AppTheme.textMedium,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseCell(String phase, int dap, int startDap, int endDap, List<String> row, Map<String, int> activityCounts) {
    Color cellColor;
    String displayText = '';

    // Ambil Field Number dari row
    final fieldNumber = getValue(row, 2, ""); // Kolom C untuk FN
    final cuValue = getValue(row, 43, ""); // Kolom AR untuk CU data

    // Cek aktivitas untuk setiap fase
    final activityCount = activityCounts[fieldNumber] ?? 0;

    if (phase == 'Veg') {
      if (activityCount > 0) {
        cellColor = AppTheme.success;
        displayText = activityCount.toString(); // Tampilkan jumlah aktivitas
      } else if (dap >= startDap && dap <= endDap) {
        cellColor = AppTheme.warning;
        displayText = '●';
      } else if (dap > endDap) {
        cellColor = AppTheme.error;
        displayText = '!';
      } else {
        cellColor = Colors.grey.shade300;
        displayText = '-';
      }
    } else if (phase.startsWith('CU')) {
      // Untuk fase CU, tampilkan data dari kolom AR
      if (cuValue.isNotEmpty && cuValue != '-') {
        cellColor = AppTheme.success;
        displayText = cuValue; // Tampilkan nilai CU
      } else if (dap >= startDap && dap <= endDap) {
        cellColor = AppTheme.warning;
        displayText = '●';
      } else if (dap > endDap) {
        cellColor = AppTheme.error;
        displayText = '!';
      } else {
        cellColor = Colors.grey.shade300;
        displayText = '-';
      }
    } else if (phase.startsWith('Gen')) {
      // Logika untuk Generative - Audit
      if (dap < startDap) {
        cellColor = Colors.grey.shade300;
        displayText = '-';
      } else if (dap >= startDap && dap <= endDap) {
        cellColor = AppTheme.warning;
        displayText = '●';
      } else if (dap > endDap && dap <= endDap + 7) {
        cellColor = AppTheme.success;
        displayText = '✓';
      } else {
        cellColor = AppTheme.error;
        displayText = '!';
      }
    } else {
      // Logika untuk Harvest
      if (dap < startDap) {
        cellColor = Colors.grey.shade300;
        displayText = '-';
      } else if (dap >= startDap && dap <= endDap) {
        cellColor = AppTheme.warning;
        displayText = '●';
      } else if (dap > endDap) {
        cellColor = AppTheme.error;
        displayText = '!';
      } else {
        cellColor = Colors.grey.shade300;
        displayText = '-';
      }
    }

    return Container(
      width: 50,
      height: 32,
      decoration: BoxDecoration(
        color: cellColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: cellColor.withAlpha(127),
          width: 1,
        ),
      ),
      child: Center(
        child: Text(
          displayText,
          style: TextStyle(
            color: cellColor == Colors.grey.shade300 ? AppTheme.textMedium : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: displayText.length > 1 ? 12 : 14, // Sesuaikan ukuran font untuk angka
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: color.withAlpha(127),
              width: 1,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}