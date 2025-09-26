import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'generative_detail_screen.dart'; // Pastikan file ini ada

class GenerativeSliverListBuilder extends StatelessWidget {
  final List<List<String>> filteredData;
  final String? selectedRegion;
  final Function(String) onItemTap;
  final Map<String, int> activityCounts;

  const GenerativeSliverListBuilder({
    super.key,
    required this.filteredData,
    this.selectedRegion,
    required this.onItemTap,
    this.activityCounts = const {},
  });

  String getValue(List<String> row, int index, String defaultValue) {
    if (index < row.length) {
      return row[index];
    }
    return defaultValue;
  }

  int _calculateDAP(List<String> row) {
    try {
      final plantingDate = getValue(row, 9, ''); // Kolom 9 untuk tanggal tanam
      if (plantingDate.isEmpty) return 0;

      final parsedDate = DateFormat('dd/MM/yyyy').parse(_convertToDateIfNecessary(plantingDate));
      final today = DateTime.now();
      return today.difference(parsedDate).inDays;
    } catch (e) {
      return 0; // Kembalikan 0 jika ada error parsing
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
      // Abaikan jika error
    }
    return value;
  }

  String _formatPlantingDate(String dateStr) {
    try {
      final parsedNumber = double.tryParse(dateStr);
      if (parsedNumber != null) {
        final date = DateTime(1899, 12, 30).add(Duration(days: parsedNumber.toInt()));
        return DateFormat('dd MMM yyyy').format(date);
      }
      final parsedDate = DateFormat('dd/MM/yyyy').parse(dateStr);
      return DateFormat('dd MMM yyyy').format(parsedDate);
    } catch (e) {
      return dateStr; // Kembalikan string asli jika gagal
    }
  }

  Color _getDapColor(int dap) {
    if (dap <= 70) {
      return Colors.lightGreen;
    } else if (dap <= 80) {
      return Colors.lime;
    } else if (dap <= 90) {
      return Colors.amber;
    } else if (dap <= 100) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  // Menentukan status audit berdasarkan dua kolom
  String getGenerativeStatus(String cekResult, String cekProses) {
    if (cekResult.toLowerCase() == "audited" && cekProses.toLowerCase() == "audited") {
      return "Sampun";
    } else if ((cekResult.toLowerCase() == "audited" && cekProses.toLowerCase() == "not audited") ||
        (cekResult.toLowerCase() == "not audited" && cekProses.toLowerCase() == "audited")) {
      return "Dereng Jangkep";
    } else if (cekResult.toLowerCase() == "not audited" && cekProses.toLowerCase() == "not audited") {
      return "Dereng Blas";
    }
    return "Unknown";
  }

  // Mendapatkan warna solid berdasarkan status
  Color getStatusColor(String status) {
    switch (status) {
      case "Sampun":
        return Colors.green;
      case "Dereng Jangkep":
        return Colors.orange;
      case "Dereng Blas":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Mendapatkan warna gradien untuk latar belakang badge
  List<Color> getStatusGradient(String status) {
    switch (status) {
      case "Sampun":
        return [Colors.green.shade400, Colors.green.shade600];
      case "Dereng Jangkep":
        return [Colors.orange.shade400, Colors.orange.shade600];
      case "Dereng Blas":
        return [Colors.red.shade400, Colors.red.shade600];
      default:
        return [Colors.grey.shade400, Colors.grey.shade600];
    }
  }

  // Mendapatkan warna terang untuk latar belakang kartu
  Color getStatusLightColor(String status) {
    switch (status) {
      case "Sampun":
        return Colors.green.shade50;
      case "Dereng Jangkep":
        return Colors.orange.shade50;
      case "Dereng Blas":
        return Colors.red.shade50;
      default:
        return Colors.grey.shade50;
    }
  }

  // Mendapatkan ikon berdasarkan status
  IconData getStatusIcon(String status) {
    switch (status) {
      case "Sampun":
        return Icons.check_circle;
      case "Dereng Jangkep":
        return Icons.hourglass_empty;
      case "Dereng Blas":
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  // Widget untuk membangun baris info dengan ikon
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 4),
        Expanded(
          child: RichText(
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.black54,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Menggunakan SliverList sebagai pengganti ListView.builder
    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          final row = filteredData[index];
          final status = getGenerativeStatus(getValue(row, 72, ""), getValue(row, 73, ""));
          final dap = _calculateDAP(row);
          final fieldNumber = getValue(row, 2, "Unknown");
          final farmerName = getValue(row, 3, "Unknown");
          final growerName = getValue(row, 4, "Unknown");
          final hybrid = getValue(row, 5, "Unknown");
          final effectiveArea = getValue(row, 8, "0");
          final rawPlantingDate = getValue(row, 9, "Unknown");
          final plantingDate = _formatPlantingDate(rawPlantingDate);
          final desa = getValue(row, 11, "Unknown");
          final kecamatan = getValue(row, 12, "Unknown");
          final kabupaten = getValue(row, 13, "Unknown");
          final fa = getValue(row, 14, "Unknown");
          final fieldSpv = getValue(row, 15, "Unknown");
          final weekOfGenerative = getValue(row, 29, "Unknown");
          final fi = getValue(row, 31, "Unknown");
          final activityCount = activityCounts[fieldNumber] ?? 0;

          // Mendapatkan properti visual berdasarkan status
          final statusColor = getStatusColor(status);
          final statusGradient = getStatusGradient(status);
          final statusLightColor = getStatusLightColor(status);
          final statusIcon = getStatusIcon(status);

          // UI Kartu di bawah ini sama persis dengan yang ada di GenerativeListViewBuilder
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white, statusLightColor],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withAlpha(25),
                    blurRadius: 8,
                    spreadRadius: 1,
                    offset: const Offset(0, 3),
                  ),
                ],
                border: Border.all(
                  color: statusColor.withAlpha(102),
                  width: 1.5,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => GenerativeDetailScreen(
                          fieldNumber: fieldNumber,
                          region: selectedRegion ?? 'Unknown Region',
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Baris Header: Nomor Lahan dan Status
                        Row(
                          children: [
                            Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(20),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Hero(
                                    tag: 'generative_$fieldNumber',
                                    child: Image.asset(
                                      'assets/generative.png',
                                      height: 40,
                                      width: 40,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _getDapColor(dap),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$dap DAP',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          fieldNumber,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: statusGradient,
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: statusColor.withAlpha(60),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              statusIcon,
                                              color: Colors.white,
                                              size: 14,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              status,
                                              style: const TextStyle(
                                                fontFamily: 'Manrope',
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  // Info Farmer dan Grower
                                  Row(
                                    children: [
                                      Expanded(child: RichText(overflow: TextOverflow.ellipsis, text: TextSpan(style: const TextStyle(fontSize: 13, color: Colors.black87), children: [const TextSpan(text: 'Farmer: ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)), TextSpan(text: farmerName)]))),
                                      const SizedBox(width: 8),
                                      Expanded(child: RichText(overflow: TextOverflow.ellipsis, text: TextSpan(style: const TextStyle(fontSize: 13, color: Colors.black87), children: [const TextSpan(text: 'Grower: ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)), TextSpan(text: growerName)]))),
                                    ],
                                  ),
                                  // Info Hybrid dan Area
                                  Row(
                                    children: [
                                      Expanded(child: RichText(overflow: TextOverflow.ellipsis, text: TextSpan(style: const TextStyle(fontSize: 13, color: Colors.black87), children: [const TextSpan(text: 'Hybrid: ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)), TextSpan(text: hybrid)]))),
                                      const SizedBox(width: 8),
                                      Expanded(child: RichText(overflow: TextOverflow.ellipsis, text: TextSpan(style: const TextStyle(fontSize: 13, color: Colors.black87), children: [const TextSpan(text: 'Area: ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)), TextSpan(text: '$effectiveArea Ha')]))),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Pembatas
                        Container(height: 1, color: statusColor.withAlpha(51)),
                        const SizedBox(height: 12),
                        // Info Lokasi dan Personel
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Location & Planting', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54)),
                                  const SizedBox(height: 4),
                                  _buildInfoRow(icon: Icons.calendar_today, label: 'Planted', value: plantingDate, iconColor: Colors.green),
                                  const SizedBox(height: 2),
                                  _buildInfoRow(icon: Icons.location_on, label: 'Desa', value: desa, iconColor: Colors.green),
                                  const SizedBox(height: 2),
                                  _buildInfoRow(icon: Icons.location_city, label: 'Kec', value: kecamatan, iconColor: Colors.green),
                                  const SizedBox(height: 2),
                                  _buildInfoRow(icon: Icons.map, label: 'Kab', value: kabupaten, iconColor: Colors.green),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Personnel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54)),
                                  const SizedBox(height: 4),
                                  _buildInfoRow(icon: Icons.person, label: 'F.SPV', value: fieldSpv, iconColor: Colors.blue),
                                  const SizedBox(height: 2),
                                  _buildInfoRow(icon: Icons.people, label: 'FA', value: fa, iconColor: Colors.blue),
                                  const SizedBox(height: 2),
                                  _buildInfoRow(icon: Icons.people, label: 'FI', value: fi, iconColor: Colors.blue),
                                  const SizedBox(height: 2),
                                  _buildInfoRow(icon: Icons.calendar_month, label: 'Week', value: weekOfGenerative, iconColor: Colors.blue),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Baris Bawah: Jumlah Aktivitas dan Tombol Detail
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: activityCount == 0 ? [Colors.red.shade50, Colors.red.shade100] : (activityCount < 3 ? [Colors.orange.shade50, Colors.orange.shade100] : [Colors.green.shade50, Colors.green.shade100]), begin: Alignment.topLeft, end: Alignment.bottomRight),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: activityCount == 0 ? Colors.red.shade200 : (activityCount < 3 ? Colors.orange.shade200 : Colors.green.shade200), width: 1.0),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(activityCount == 0 ? Icons.history_toggle_off : (activityCount < 3 ? Icons.history : Icons.history_edu), color: activityCount == 0 ? Colors.red.shade700 : (activityCount < 3 ? Colors.orange.shade700 : Colors.green.shade700), size: 16),
                                  const SizedBox(width: 6),
                                  Text(activityCount == 0 ? 'Not Visited' : 'Visited $activityCount kali', style: TextStyle(color: activityCount == 0 ? Colors.red.shade700 : (activityCount < 3 ? Colors.orange.shade700 : Colors.green.shade700), fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: statusGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [BoxShadow(color: statusColor.withAlpha(60), blurRadius: 4, offset: const Offset(0, 2))],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    onItemTap(fieldNumber);
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.visibility, size: 16, color: Colors.white),
                                        SizedBox(width: 4),
                                        Text('View Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        childCount: filteredData.length,
      ),
    );
  }
}