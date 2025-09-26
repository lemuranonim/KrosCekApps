import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shimmer/shimmer.dart';
import 'package:lottie/lottie.dart';

import 'data_service.dart';

class DashboardAnalyticsTab extends StatefulWidget {
  final DataService dataService;
  final bool isLoading;

  const DashboardAnalyticsTab({
    super.key,
    required this.dataService,
    required this.isLoading,
  });

  @override
  State<DashboardAnalyticsTab> createState() => _DashboardAnalyticsTabState();
}

class _DashboardAnalyticsTabState extends State<DashboardAnalyticsTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Map<String, dynamic> _dashboardData = {};
  bool _isLoading = true;

  var _dashboardDataCache = <String, dynamic>{};
  final _cacheDuration = const Duration(minutes: 5);
  DateTime? _lastCacheTime;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(DashboardAnalyticsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Muat ulang data jika state loading dari parent berubah (menandakan ada aksi refresh/ganti region)
    if (widget.isLoading && !oldWidget.isLoading) {
      _loadData();
    }
    // Jika parent sudah selesai loading, update state di sini
    if (!widget.isLoading && oldWidget.isLoading) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final now = DateTime.now();
      // Logika cache sederhana
      if (_lastCacheTime != null && now.difference(_lastCacheTime!) < _cacheDuration && _dashboardDataCache.isNotEmpty) {
        if (mounted) {
          setState(() {
            _dashboardData = _dashboardDataCache;
            _isLoading = false;
          });
        }
        return;
      }

      // Ambil data summary dari service
      final dashboardData = await widget.dataService.getDashboardSummary();

      if (mounted) {
        setState(() {
          _dashboardData = dashboardData;
          _dashboardDataCache = Map.from(dashboardData);
          _lastCacheTime = now;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // Tampilkan pesan error jika perlu
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data analitik: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    // Gunakan _isLoading dari state lokal yang disinkronkan dengan widget.isLoading
    final showLoading = _isLoading;

    return RefreshIndicator(
      onRefresh: _loadData,
      color: Colors.green,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(isTablet ? 24.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSection(isLoading: showLoading),
            SizedBox(height: isTablet ? 32 : 24),

            if (isTablet)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _buildQuickStatsSection(isLoading: showLoading)),
                  const SizedBox(width: 24),
                  Expanded(flex: 2, child: _buildStatusDistributionSection(isLoading: showLoading)),
                ],
              )
            else
              Column(
                children: [
                  _buildQuickStatsSection(isLoading: showLoading),
                  const SizedBox(height: 32),
                  _buildStatusDistributionSection(isLoading: showLoading),
                ],
              ),

            const SizedBox(height: 32),
            _buildChartSection(isLoading: showLoading),
            const SizedBox(height: 32),
            _buildRecentActivitiesSection(isLoading: showLoading),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // Semua fungsi build helper di bawah ini sekarang menerima parameter `isLoading`
  // untuk memastikan UI menampilkan state yang benar.

  Widget _buildHeaderSection({required bool isLoading}) {
    final selectedRegion = widget.dataService.getSelectedRegion();
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.green.shade800, Colors.green.shade600],
          stops: const [0.3, 0.9],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withAlpha(76),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sugêng Rawuh, Luur',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(DateTime.now()),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white.withAlpha(204),
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: _loadData,
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                tooltip: 'Refresh Data',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildHeaderStat(
                  isLoading: isLoading,
                  title: 'Total Pengguna',
                  value: '${_dashboardData['totalUsers'] ?? 0}',
                  icon: Icons.people_outlined,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildHeaderStat(
                  isLoading: isLoading,
                  title: 'Aktivitas Hari Ini',
                  value: '${_dashboardData['aktivitasToday'] ?? 0}',
                  icon: Icons.trending_up_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildHeaderStat(
                  isLoading: isLoading,
                  title: 'Absensi Hari Ini',
                  value: '${_dashboardData['absensiToday'] ?? 0}',
                  icon: Icons.check_circle_outline,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildHeaderStat(
                  isLoading: isLoading,
                  title: 'Region Aktif',
                  value: selectedRegion.isEmpty ? 'Semua' : selectedRegion,
                  icon: Icons.location_on_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStat({
    required bool isLoading,
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(38),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(51),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withAlpha(204),
                  ),
                ),
                isLoading && title != 'Region Aktif'
                    ? Shimmer.fromColors(
                  baseColor: Colors.white.withAlpha(127),
                  highlightColor: Colors.white.withAlpha(204),
                  child: Container(
                    height: 18,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                )
                    : Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsSection({required bool isLoading}) {
    if (isLoading) return _buildLoadingQuickStats();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ringkasan Cepat',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildQuickStatCard(
                title: 'Absensi Masuk',
                value: '${_dashboardData['absensiStatusCounts']?['Masuk'] ?? 0}',
                icon: Icons.login_rounded,
                color: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickStatCard(
                title: 'Aktivitas Selesai',
                value: '${_dashboardData['aktivitasTypeCounts']?['Selesai'] ?? 0}',
                icon: Icons.check_circle_outline,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoadingQuickStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Container(
            width: 150,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: color.withAlpha(25),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              Icon(
                Icons.more_horiz,
                color: Colors.grey.shade400,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection({required bool isLoading}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
              Text(
                'Aktivitas',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              // Opsi periode bisa diimplementasikan lebih lanjut nanti
            ],
          ),
          const SizedBox(height: 24),
          isLoading
              ? Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          )
              : SizedBox(
            height: 200,
            child: FutureBuilder<List<FlSpot>>(
              future: widget.dataService.getActivityTrendData(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Gagal memuat data chart',
                      style: TextStyle(color: Colors.red.shade400),
                    ),
                  );
                }

                final spots = snapshot.data ?? [];

                if (spots.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bar_chart_outlined,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Tidak ada data aktivitas',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Temukan nilai y maksimum untuk mengatur skala chart
                final maxY = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);

                return LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: (maxY / 4).ceilToDouble(), // Atur interval grid horizontal
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Colors.grey.shade200,
                          strokeWidth: 1,
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: (spots.length / 5).ceilToDouble(), // Tampilkan sekitar 5 label
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() >= spots.length) return const SizedBox.shrink();
                            final now = DateTime.now();
                            final date = now.subtract(Duration(days: (spots.length - 1 - value.toInt())));
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                DateFormat('dd/MM').format(date),
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 10,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: (maxY / 4).ceilToDouble(), // Atur interval label vertikal
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value.toInt().toString(),
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 10,
                              ),
                            );
                          },
                          reservedSize: 30,
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: spots.length.toDouble() - 1,
                    minY: 0,
                    maxY: maxY + (maxY * 0.1), // Beri sedikit ruang di atas
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        gradient: LinearGradient(
                          colors: [Colors.green.shade300, Colors.green.shade700],
                        ),
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 4,
                              color: Colors.white,
                              strokeWidth: 2,
                              strokeColor: Colors.green.shade700,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.green.shade200.withAlpha(102),
                              Colors.green.shade200.withAlpha(0),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDistributionSection({required bool isLoading}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          Text(
            'Distribusi Status',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 24),
          isLoading
              ? Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          )
              : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Absensi', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                    const SizedBox(height: 16),
                    ..._buildStatusBars(
                      _dashboardData['absensiStatusCounts'],
                      [Colors.green.shade500, Colors.orange.shade500, Colors.red.shade500, Colors.blue.shade500],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Aktivitas', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                    const SizedBox(height: 16),
                    ..._buildStatusBars(
                      _dashboardData['aktivitasTypeCounts'],
                      [Colors.purple.shade500, Colors.teal.shade500, Colors.amber.shade500, Colors.indigo.shade500],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ✅ FUNGSI YANG DIPERBAIKI
  List<Widget> _buildStatusBars(dynamic data, List<Color> colors) {
    // Pastikan data adalah Map, jika tidak atau null, kembalikan state kosong.
    if (data == null || data is! Map) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 32.0),
          child: Center(child: Text('Tidak ada data', style: TextStyle(color: Colors.grey))),
        ),
      ];
    }

    // Konversi ke Map<String, dynamic> untuk keamanan
    final statusCounts = Map<String, dynamic>.from(data);
    if(statusCounts.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 32.0),
          child: Center(child: Text('Tidak ada data', style: TextStyle(color: Colors.grey))),
        ),
      ];
    }

    // Ubah nilai menjadi num untuk keamanan, lalu hitung total.
    final total = statusCounts.values.fold<num>(0, (sum, count) => sum + (num.tryParse(count.toString()) ?? 0));

    // Urutkan berdasarkan nilai (descending)
    final sortedEntries = statusCounts.entries.toList()
      ..sort((a, b) {
        final valA = num.tryParse(a.value.toString()) ?? 0;
        final valB = num.tryParse(b.value.toString()) ?? 0;
        return valB.compareTo(valA);
      });

    return sortedEntries.asMap().entries.map((entry) {
      final index = entry.key;
      final status = entry.value.key;
      final count = num.tryParse(entry.value.value.toString()) ?? 0;
      final percentage = total > 0 ? (count / total * 100) : 0;
      final color = index < colors.length ? colors[index] : Colors.grey;

      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    status,
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '$count (${percentage.toStringAsFixed(1)}%)',
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Stack(
              children: [
                Container(
                  height: 8,
                  width: double.infinity,
                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                ),
                FractionallySizedBox(
                  widthFactor: percentage / 100,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildRecentActivitiesSection({required bool isLoading}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
              Text(
                'Aktivitas Terbaru',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
              ),
              TextButton(
                onPressed: () => DefaultTabController.of(context).animateTo(2),
                child: Text(
                  'Lihat Semua',
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green.shade700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          isLoading
              ? _buildLoadingActivities()
              : FutureBuilder<List<AktivitasData>>(
            future: widget.dataService.getRecentActivities(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingActivities();
              } else if (snapshot.hasError) {
                return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red))));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        Lottie.asset('assets/animations/empty_data.json', width: 120, height: 120),
                        const SizedBox(height: 16),
                        Text('Belum ada aktivitas terbaru', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                      ],
                    ),
                  ),
                );
              }

              final activities = snapshot.data!;
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: activities.length,
                separatorBuilder: (context, index) => Divider(color: Colors.grey.shade200, height: 1),
                itemBuilder: (context, index) => _buildActivityItem(activities[index]),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingActivities() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      separatorBuilder: (context, index) => Divider(color: Colors.grey.shade200, height: 1),
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Row(
              children: [
                Container(width: 40, height: 40, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: double.infinity, height: 14, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                      const SizedBox(height: 8),
                      Container(width: 100, height: 10, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActivityItem(AktivitasData activity) {
    Color statusColor;
    IconData statusIcon;

    switch (activity.status.toLowerCase()) {
      case 'selesai':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case 'ditolak':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.blue;
        statusIcon = Icons.info;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: statusColor.withAlpha(25), shape: BoxShape.circle),
            child: Icon(statusIcon, color: statusColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(activity.name, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade800), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('${activity.type} - ${activity.aksi}', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(DateFormat('dd/MM/yy').format(activity.timestamp), style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(height: 4),
              Text(DateFormat('HH:mm').format(activity.timestamp), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
            ],
          ),
        ],
      ),
    );
  }
}