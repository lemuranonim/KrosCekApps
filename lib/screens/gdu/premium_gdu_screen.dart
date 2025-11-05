import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'heat_unit_service.dart';
import 'package:intl/intl.dart';

/// GDU Monitoring Page dengan loading state
class GDUMonitoringPage extends StatefulWidget {
  final double latitude;
  final double longitude;
  final DateTime plantingDate;

  const GDUMonitoringPage({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.plantingDate,
  });

  @override
  State<GDUMonitoringPage> createState() => _GDUMonitoringPageState();
}

class _GDUMonitoringPageState extends State<GDUMonitoringPage> {
  final HeatUnitService _service = HeatUnitService();
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  double _gdu = 0.0;
  double _chu = 0.0;
  int _dap = 0;
  Map<String, dynamic>? _gduStatus;
  Map<String, dynamic>? _chuStatus;
  String? _alert;
  DateTime? _estimatedHarvestDate;
  double _phaseProgress = 0.0;
  List<Map<String, dynamic>> _historicalGDU = [];
  double _growthVelocity = 0.0;
  Map<String, dynamic>? _weatherImpact;

  // 🆕 DAP-based phase info
  Map<String, dynamic>? _phaseInfoByDAP;
  String? _syncRecommendation;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      _dap = DateTime.now().difference(widget.plantingDate).inDays;

      final heatUnits = await _service.fetchHistoricalHeatUnits(
        latitude: widget.latitude,
        longitude: widget.longitude,
        plantingDate: widget.plantingDate,
      );

      _gdu = heatUnits['gdu']!;
      _chu = heatUnits['chu']!;
      _gduStatus = _service.getGDUStatus(_gdu, _dap);
      _chuStatus = _service.getCHUStatus(_chu, _dap);
      _alert = _service.checkHeatUnitAlert(_gdu, _chu, _dap);
      _estimatedHarvestDate = _service.estimateHarvestDate(widget.plantingDate, _gdu, _dap);
      _phaseProgress = _service.getPhaseProgressByDAP(_dap); // 🆕 Progress berdasarkan DAP

      // 🆕 Dapatkan info fase berdasarkan DAP
      _phaseInfoByDAP = _service.getMainPhaseInfoByDAP(_dap, _gdu);
      _syncRecommendation = _service.getGDUDAPSyncRecommendation(_gdu, _dap);

      _calculateAdditionalMetrics();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  void _calculateAdditionalMetrics() {
    _growthVelocity = _dap > 0 ? _gdu / _dap : 0;

    _historicalGDU = List.generate(_dap > 30 ? 30 : _dap, (index) {
      final dayIndex = _dap - (30 - index);
      return {
        'day': dayIndex,
        'gdu': (_gdu / _dap) * dayIndex,
        'date': widget.plantingDate.add(Duration(days: dayIndex)),
      };
    });

    final avgGDUPerDay = _dap > 0 ? _gdu / _dap : 0;
    final idealGDUPerDay = 17.5; // 🆕 Update dari 15.0 ke 17.5

    if (avgGDUPerDay >= idealGDUPerDay * 1.1) {
      _weatherImpact = {
        'status': 'Sangat Baik',
        'icon': Icons.wb_sunny,
        'color': Colors.green,
        'description': 'Kondisi cuaca optimal untuk pertumbuhan',
        'percentage': ((avgGDUPerDay / idealGDUPerDay - 1) * 100).clamp(0.0, 100.0),
      };
    } else if (avgGDUPerDay >= idealGDUPerDay * 0.9) {
      _weatherImpact = {
        'status': 'Baik',
        'icon': Icons.wb_cloudy,
        'color': Colors.blue,
        'description': 'Pertumbuhan normal sesuai ekspektasi',
        'percentage': ((avgGDUPerDay / idealGDUPerDay) * 100).clamp(0.0, 100.0),
      };
    } else {
      _weatherImpact = {
        'status': 'Kurang Optimal',
        'icon': Icons.cloud,
        'color': Colors.orange,
        'description': 'Suhu lebih rendah dari ideal, pertumbuhan lebih lambat',
        'percentage': ((avgGDUPerDay / idealGDUPerDay) * 100).clamp(0.0, 100.0),
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildLoadingScreen();
    if (_hasError) return _buildErrorScreen();

    return PremiumGDUScreen(
      gdu: _gdu,
      chu: _chu,
      dap: _dap,
      gduStatus: _gduStatus!,
      chuStatus: _chuStatus!,
      alert: _alert,
      estimatedHarvestDate: _estimatedHarvestDate,
      phaseProgress: _phaseProgress,
      historicalGDU: _historicalGDU,
      growthVelocity: _growthVelocity,
      weatherImpact: _weatherImpact!,
      phaseInfoByDAP: _phaseInfoByDAP, // 🆕
      syncRecommendation: _syncRecommendation, // 🆕
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha((0.1 * 255).toInt()),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Colors.green),
                  strokeWidth: 3,
                ),
              ),
              SizedBox(height: 24),
              Text('Mengambil Data Cuaca...', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('Menghitung GDU & CHU', style: TextStyle(color: Colors.white.withAlpha((0.6 * 255).toInt()), fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha((0.1 * 255).toInt()),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.red.withAlpha((0.3 * 255).toInt())),
                  ),
                  child: Icon(Icons.error_outline, color: Colors.red, size: 64),
                ),
                SizedBox(height: 24),
                Text('Gagal Memuat Data', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                SizedBox(height: 12),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Text(_errorMessage ?? 'Terjadi kesalahan', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withAlpha((0.6 * 255).toInt()), fontSize: 14)),
                ),
                SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _loadData,
                  icon: Icon(Icons.refresh),
                  label: Text('Coba Lagi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PremiumGDUScreen extends StatefulWidget {
  final double gdu;
  final double chu;
  final int dap;
  final Map<String, dynamic> gduStatus;
  final Map<String, dynamic> chuStatus;
  final String? alert;
  final DateTime? estimatedHarvestDate;
  final double phaseProgress;
  final List<Map<String, dynamic>> historicalGDU;
  final double growthVelocity;
  final Map<String, dynamic> weatherImpact;
  final Map<String, dynamic>? phaseInfoByDAP; // 🆕
  final String? syncRecommendation; // 🆕

  const PremiumGDUScreen({
    super.key,
    required this.gdu,
    required this.chu,
    required this.dap,
    required this.gduStatus,
    required this.chuStatus,
    this.alert,
    this.estimatedHarvestDate,
    required this.phaseProgress,
    required this.historicalGDU,
    required this.growthVelocity,
    required this.weatherImpact,
    this.phaseInfoByDAP,
    this.syncRecommendation,
  });

  @override
  State<PremiumGDUScreen> createState() => _PremiumGDUScreenState();
}

class _PremiumGDUScreenState extends State<PremiumGDUScreen> with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _progressAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(duration: Duration(milliseconds: 1800), vsync: this);
    _pulseController = AnimationController(duration: Duration(milliseconds: 2000), vsync: this)..repeat(reverse: true);
    _fadeController = AnimationController(duration: Duration(milliseconds: 800), vsync: this);

    _progressAnimation = Tween<double>(begin: 0, end: widget.phaseProgress / 100).animate(
        CurvedAnimation(parent: _progressController, curve: Curves.easeOutCubic)
    );
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut)
    );

    _progressController.forward();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: CustomScrollView(
              physics: BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        SizedBox(height: 24),
                        if (widget.alert != null) ...[
                          _buildAlertCard(),
                          SizedBox(height: 16),
                        ],
                        // 🆕 Sync Warning Card
                        if (widget.syncRecommendation != null) ...[
                          _buildSyncWarningCard(),
                          SizedBox(height: 16),
                        ],
                        _buildMainGDUCard(),
                        SizedBox(height: 16),
                        _buildStatsRow(),
                        SizedBox(height: 16),
                        _buildPhaseInsightsCard(),
                        SizedBox(height: 16),
                        _buildWeatherImpactCard(),
                        SizedBox(height: 16),
                        _buildGrowthVelocityCard(),
                        SizedBox(height: 16),
                        _buildPhaseTimeline(),
                        SizedBox(height: 16),
                        _buildMilestoneCountdown(),
                        SizedBox(height: 16),
                        _buildComparisonChart(),
                        SizedBox(height: 16),
                        _buildCHUCard(),
                        SizedBox(height: 16),
                        _buildHarvestCard(),
                        SizedBox(height: 16),
                        _buildRecommendationCard(),
                        SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.green, Colors.green.shade700]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.green.withAlpha((0.3 * 255).toInt()), blurRadius: 12, offset: Offset(0, 4))],
          ),
          child: Icon(Icons.agriculture, color: Colors.white, size: 28),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('GDU Monitor', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
              Text('Pemantauan Fase Pertumbuhan Real-time', style: TextStyle(color: Colors.white.withAlpha((0.6 * 255).toInt()), fontSize: 13)),
            ],
          ),
        ),
        IconButton(icon: Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ],
    );
  }

  Widget _buildAlertCard() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + (_pulseAnimation.value - 1.0) * 0.3,
          child: Container(
            padding: EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.orange.withAlpha((0.25 * 255).toInt()), Colors.deepOrange.withAlpha((0.15 * 255).toInt())]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.withAlpha((0.4 * 255).toInt()), width: 1.5),
              boxShadow: [BoxShadow(color: Colors.orange.withAlpha((0.2 * 255).toInt()), blurRadius: 12, offset: Offset(0, 4))],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.orange.withAlpha((0.2 * 255).toInt()), shape: BoxShape.circle),
                  child: Icon(Icons.warning_amber_rounded, color: Colors.orange[300] ?? Colors.orange, size: 24),
                ),
                SizedBox(width: 14),
                Expanded(child: Text(widget.alert ?? '', style: TextStyle(color: Colors.orange[100] ?? Colors.orange.shade100, fontSize: 13, fontWeight: FontWeight.w500, height: 1.4))),
              ],
            ),
          ),
        );
      },
    );
  }

  // 🆕 Sync Warning Card
  Widget _buildSyncWarningCard() {
    final phaseInfo = widget.phaseInfoByDAP;
    if (phaseInfo == null || phaseInfo['isSynced'] == true) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.blue.withAlpha((0.25 * 255).toInt()), Colors.cyan.withAlpha((0.15 * 255).toInt())]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withAlpha((0.4 * 255).toInt()), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.blue.withAlpha((0.2 * 255).toInt()), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.blue.withAlpha((0.2 * 255).toInt()), shape: BoxShape.circle),
            child: Icon(Icons.info_outline, color: Colors.blue[300] ?? Colors.blue, size: 24),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Perbedaan Fase DAP vs GDU',
                  style: TextStyle(color: Colors.blue[100] ?? Colors.blue.shade100, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  widget.syncRecommendation ?? '',
                  style: TextStyle(color: Colors.blue[50] ?? Colors.blue.shade50, fontSize: 12, fontWeight: FontWeight.w500, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainGDUCard() {
    // 🆕 Gunakan fase berdasarkan DAP
    final phaseInfo = widget.phaseInfoByDAP;
    final phaseByDAP = phaseInfo?['name'] ?? widget.gduStatus['mainPhase'];
    final color = widget.gduStatus['color'] as Color;

    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        return Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withAlpha((0.25 * 255).toInt()), color.withAlpha((0.08 * 255).toInt())],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withAlpha((0.4 * 255).toInt()), width: 1.5),
            boxShadow: [BoxShadow(color: color.withAlpha((0.3 * 255).toInt()), blurRadius: 24, offset: Offset(0, 12))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [color.withAlpha((0.3 * 255).toInt()), color.withAlpha((0.15 * 255).toInt())]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(widget.gduStatus['icon'], color: color, size: 32),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.gduStatus['phase'], style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                        SizedBox(height: 2),
                        // 🆕 Tampilkan fase berdasarkan DAP
                        Text('Fase: $phaseByDAP', style: TextStyle(color: Colors.white.withAlpha((0.5 * 255).toInt()), fontSize: 12, letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: color.withAlpha((0.25 * 255).toInt()),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color.withAlpha((0.4 * 255).toInt())),
                    ),
                    child: Text('${widget.dap} DAP', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Text(widget.gduStatus['status'], style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, height: 1.3)),
              SizedBox(height: 10),
              Text(widget.gduStatus['description'], style: TextStyle(color: Colors.white.withAlpha((0.7 * 255).toInt()), fontSize: 14, height: 1.6)),
              SizedBox(height: 24),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.black.withAlpha((0.2 * 255).toInt()), borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.wb_sunny, color: Colors.amber, size: 16),
                              SizedBox(width: 6),
                              Text('GDU Akumulasi', style: TextStyle(color: Colors.white.withAlpha((0.6 * 255).toInt()), fontSize: 12)),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text('${widget.gdu.toStringAsFixed(1)} °C', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -1)),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 50, color: Colors.white.withAlpha((0.2 * 255).toInt())),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.schedule, color: Colors.blue[300], size: 16),
                              SizedBox(width: 6),
                              Text('Fase DAP', style: TextStyle(color: Colors.white.withAlpha((0.6 * 255).toInt()), fontSize: 12)),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(phaseByDAP, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 🆕 Progress berdasarkan DAP
                      Text('Progress Fase $phaseByDAP', style: TextStyle(color: Colors.white.withAlpha((0.8 * 255).toInt()), fontSize: 13, fontWeight: FontWeight.w500)),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: color.withAlpha((0.2 * 255).toInt()), borderRadius: BorderRadius.circular(12)),
                        child: Text('${widget.phaseProgress.toStringAsFixed(1)}%', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        Container(height: 10, decoration: BoxDecoration(color: Colors.white.withAlpha((0.1 * 255).toInt()), borderRadius: BorderRadius.circular(12))),
                        FractionallySizedBox(
                          widthFactor: _progressAnimation.value,
                          child: Container(
                            height: 10,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [color, color.withAlpha((0.7 * 255).toInt())]),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [BoxShadow(color: color.withAlpha((0.6 * 255).toInt()), blurRadius: 10)],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.trending_up, color: Colors.white.withAlpha((0.5 * 255).toInt()), size: 14),
                      SizedBox(width: 6),
                      // 🆕 Info hari tersisa berdasarkan DAP
                      Text(
                        '${phaseInfo?['dapToNextPhase'] ?? 0} hari lagi ke fase berikutnya',
                        style: TextStyle(color: Colors.white.withAlpha((0.5 * 255).toInt()), fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: _buildStatCard('Rata-rata GDU', (widget.gdu / widget.dap).toStringAsFixed(1), '°C/hari', Icons.trending_up, Colors.blue)),
        SizedBox(width: 12),
        Expanded(child: _buildStatCard('CHU Total', widget.chu.toStringAsFixed(0), 'units', Icons.thermostat, Colors.purple)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, String unit, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.06 * 255).toInt()),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha((0.12 * 255).toInt())),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withAlpha((0.15 * 255).toInt()), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              SizedBox(width: 4),
              Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Text(unit, style: TextStyle(color: Colors.white.withAlpha((0.5 * 255).toInt()), fontSize: 11)),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(label, style: TextStyle(color: Colors.white.withAlpha((0.6 * 255).toInt()), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildPhaseInsightsCard() {
    final insights = _getPhaseInsights();

    return Container(
      padding: EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.indigo.withAlpha((0.25 * 255).toInt()), Colors.purple.withAlpha((0.15 * 255).toInt())],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.indigo.withAlpha((0.4 * 255).toInt()), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.indigo.withAlpha((0.2 * 255).toInt()),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.insights, color: Colors.indigo[200] ?? Colors.indigo, size: 24),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Fase Insights', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('Analisis pertumbuhan saat ini', style: TextStyle(color: Colors.white60, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          ...insights.map((insight) => Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: Container(
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha((0.2 * 255).toInt()),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withAlpha((0.12 * 255).toInt())),
              ),
              child: Row(
                children: [
                  Icon(insight['icon'] as IconData? ?? Icons.info, color: insight['color'] as Color? ?? Colors.white, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(insight['title'] as String? ?? '', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                        SizedBox(height: 4),
                        Text(insight['value'] as String? ?? '', style: TextStyle(color: insight['color'] as Color? ?? Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getPhaseInsights() {
    final avgGDUPerDay = widget.dap > 0 ? widget.gdu / widget.dap : 0;
    final phaseInfo = widget.phaseInfoByDAP;
    final daysToNext = phaseInfo?['dapToNextPhase'] ?? 0;

    return [
      {
        'icon': Icons.speed,
        'color': Colors.cyan[300] ?? Colors.cyan,
        'title': 'Laju Akumulasi',
        'value': '${avgGDUPerDay.toStringAsFixed(1)} GDU/hari',
      },
      {
        'icon': Icons.event,
        'color': Colors.amber[300] ?? Colors.amber,
        'title': 'Hari ke Fase Berikutnya',
        'value': '$daysToNext hari lagi (DAP ${widget.dap + daysToNext})',
      },
      {
        'icon': Icons.check_circle,
        'color': Colors.green[300] ?? Colors.green,
        'title': 'Status Pertumbuhan',
        'value': _getGrowthStatus(),
      },
    ];
  }

  String _getGrowthStatus() {
    final avgGDUPerDay = widget.dap > 0 ? widget.gdu / widget.dap : 0;
    if (avgGDUPerDay >= 17.5) return 'Optimal';
    if (avgGDUPerDay >= 15) return 'Baik';
    return 'Perlu Perhatian';
  }

  Widget _buildWeatherImpactCard() {
    final impact = widget.weatherImpact;
    final color = impact['color'] as Color;
    final percentage = (impact['percentage'] as double?) ?? 0.0;

    return Container(
      padding: EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withAlpha((0.25 * 255).toInt()), color.withAlpha((0.15 * 255).toInt())],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha((0.4 * 255).toInt()), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withAlpha((0.2 * 255).toInt()),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(impact['icon'] as IconData? ?? Icons.wb_cloudy, color: color, size: 24),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dampak Cuaca', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(impact['status'] as String? ?? '', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withAlpha((0.2 * 255).toInt()),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text('${percentage.toStringAsFixed(0)}%', style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          SizedBox(height: 18),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha((0.2 * 255).toInt()),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white60, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(impact['description'] as String? ?? '', style: TextStyle(color: Colors.white.withAlpha((0.7 * 255).toInt()), fontSize: 13, height: 1.4)),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                Container(height: 8, color: Colors.white.withAlpha((0.1 * 255).toInt())),
                FractionallySizedBox(
                  widthFactor: (percentage / 100).clamp(0.0, 1.0),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withAlpha((0.7 * 255).toInt())])),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrowthVelocityCard() {
    final velocity = widget.growthVelocity;
    final idealVelocity = 17.5; // 🆕 Update dari 15.0 ke 17.5
    final percentage = (velocity / idealVelocity * 100).clamp(0, 150);

    Color velocityColor;
    String velocityStatus;
    IconData velocityIcon;

    if (velocity >= idealVelocity * 1.1) {
      velocityColor = Colors.green;
      velocityStatus = 'Sangat Cepat';
      velocityIcon = Icons.rocket_launch;
    } else if (velocity >= idealVelocity * 0.9) {
      velocityColor = Colors.blue;
      velocityStatus = 'Normal';
      velocityIcon = Icons.speed;
    } else {
      velocityColor = Colors.orange;
      velocityStatus = 'Lambat';
      velocityIcon = Icons.hourglass_empty;
    }

    return Container(
      padding: EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [velocityColor.withAlpha((0.25 * 255).toInt()), velocityColor.withAlpha((0.15 * 255).toInt())],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: velocityColor.withAlpha((0.4 * 255).toInt()), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: velocityColor.withAlpha((0.2 * 255).toInt()),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(velocityIcon, color: velocityColor, size: 24),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Kecepatan Pertumbuhan', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(velocityStatus, style: TextStyle(color: velocityColor, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha((0.2 * 255).toInt()),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.trending_up, color: velocityColor, size: 16),
                          SizedBox(width: 6),
                          Text('Rata-rata', style: TextStyle(color: Colors.white60, fontSize: 11)),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(velocity.toStringAsFixed(2), style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      Text('GDU/hari', style: TextStyle(color: Colors.white60, fontSize: 11)),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha((0.2 * 255).toInt()),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.flag, color: Colors.amber, size: 16),
                          SizedBox(width: 6),
                          Text('Target', style: TextStyle(color: Colors.white60, fontSize: 11)),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(idealVelocity.toStringAsFixed(1), style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      Text('GDU/hari', style: TextStyle(color: Colors.white60, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                Container(height: 8, color: Colors.white.withAlpha((0.1 * 255).toInt())),
                FractionallySizedBox(
                  widthFactor: (percentage / 100).clamp(0.0, 1.0),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(gradient: LinearGradient(colors: [velocityColor, velocityColor.withAlpha((0.7 * 255).toInt())])),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          Text('${percentage.toStringAsFixed(0)}% dari kecepatan ideal', style: TextStyle(color: Colors.white60, fontSize: 12)),
        ],
      ),
    );
  }

  // 🆕 Phase Timeline berdasarkan DAP
  Widget _buildPhaseTimeline() {
    final phases = [
      {'phase': 'Vegetative', 'dap': 0, 'label': 'Tanam'},
      {'phase': 'Vegetative', 'dap': 25, 'label': 'V-Mid'},
      {'phase': 'Vegetative', 'dap': 50, 'label': 'V-End'},
      {'phase': 'Generative', 'dap': 79, 'label': 'G-End'},
      {'phase': 'Pre-Harvest', 'dap': 99, 'label': 'PH-End'},
      {'phase': 'Harvest', 'dap': 100, 'label': 'Panen'},
    ];

    return Container(
      padding: EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.06 * 255).toInt()),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha((0.12 * 255).toInt())),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Timeline Fase DAP', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 24),
          SizedBox(
            height: 90,
            child: CustomPaint(
              painter: DAPTimelinePainter(
                phases: phases,
                currentDAP: widget.dap,
              ),
              child: Container(),
            ),
          ),
        ],
      ),
    );
  }

  // 🆕 Milestone berdasarkan DAP
  Widget _buildMilestoneCountdown() {
    final milestones = _getMilestonesByDAP();

    return Container(
      padding: EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.06 * 255).toInt()),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha((0.12 * 255).toInt())),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Milestone Fase (DAP)', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 20),
          ...milestones.map((milestone) => Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: milestone['reached']
                      ? [Colors.green.withAlpha((0.15 * 255).toInt()), Colors.green.withAlpha((0.1 * 255).toInt())]
                      : [Colors.white.withAlpha((0.1 * 255).toInt()), Colors.white.withAlpha((0.05 * 255).toInt())],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: milestone['reached'] ? Colors.green.withAlpha((0.4 * 255).toInt()) : Colors.white.withAlpha((0.12 * 255).toInt()),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: milestone['reached'] ? Colors.green.withAlpha((0.2 * 255).toInt()) : Colors.white.withAlpha((0.1 * 255).toInt()),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      milestone['reached'] ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: milestone['reached'] ? Colors.green : Colors.white60,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(milestone['name'], style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text(milestone['description'], style: TextStyle(color: Colors.white60, fontSize: 12)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        milestone['reached'] ? '✓ Selesai' : '${milestone['daysRemaining']} hari',
                        style: TextStyle(
                          color: milestone['reached'] ? Colors.green : Colors.amber,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text('DAP ${milestone['targetDAP']}', style: TextStyle(color: Colors.white60, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getMilestonesByDAP() {
    final milestones = [
      {'name': 'Akhir Vegetative', 'targetDAP': 50, 'phase': 'Vegetative', 'description': 'Transisi ke fase generative'},
      {'name': 'Akhir Generative', 'targetDAP': 79, 'phase': 'Generative', 'description': 'Penyerbukan selesai'},
      {'name': 'Akhir Pre-Harvest', 'targetDAP': 99, 'phase': 'Pre-Harvest', 'description': 'Hampir siap panen'},
      {'name': 'Target Panen', 'targetDAP': 100, 'phase': 'Harvest', 'description': 'Masak fisiologis'},
    ];

    return milestones.map((milestone) {
      final targetDAP = milestone['targetDAP'] as int;
      final reached = widget.dap >= targetDAP;
      final daysRemaining = reached ? 0 : targetDAP - widget.dap;

      return {
        'name': milestone['name'],
        'description': milestone['description'],
        'targetDAP': targetDAP,
        'reached': reached,
        'daysRemaining': daysRemaining,
      };
    }).toList();
  }

  Widget _buildComparisonChart() {
    return Container(
      padding: EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.06 * 255).toInt()),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha((0.12 * 255).toInt())),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Perbandingan GDU', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 8),
          Text('Aktual vs Target Ideal', style: TextStyle(color: Colors.white60, fontSize: 12)),
          SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: CustomPaint(
              painter: ComparisonChartPainter(
                historicalGDU: widget.historicalGDU,
                currentGDU: widget.gdu,
                dap: widget.dap,
              ),
              child: Container(),
            ),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(Colors.green, 'Aktual'),
              SizedBox(width: 20),
              _buildLegendItem(Colors.amber.withAlpha((0.7 * 255).toInt()), 'Target Ideal'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 6),
        Text(label, style: TextStyle(color: Colors.white60, fontSize: 12)),
      ],
    );
  }

  Widget _buildCHUCard() {
    final color = widget.chuStatus['color'] as Color;
    final percentage = widget.chuStatus['percentage'] as double;

    return Container(
      padding: EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.06 * 255).toInt()),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha((0.12 * 255).toInt())),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withAlpha((0.15 * 255).toInt()),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.chuStatus['icon'], color: color, size: 24),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CHU Status', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    SizedBox(height: 2),
                    Text(widget.chuStatus['description'], style: TextStyle(color: Colors.white.withAlpha((0.6 * 255).toInt()), fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withAlpha((0.2 * 255).toInt()),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(widget.chuStatus['status'], style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha((0.1 * 255).toInt()),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: (percentage / 100).clamp(0.0, 1.0),
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [color, color.withAlpha((0.6 * 255).toInt())]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: color.withAlpha((0.5 * 255).toInt()), blurRadius: 8)],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10),
          Text('${percentage.toStringAsFixed(1)}% dari target ideal', style: TextStyle(color: Colors.white.withAlpha((0.5 * 255).toInt()), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildHarvestCard() {
    if (widget.estimatedHarvestDate == null) {
      return _buildLoadingHarvestCard();
    }

    final today = DateUtils.dateOnly(DateTime.now());
    final harvestDay = DateUtils.dateOnly(widget.estimatedHarvestDate!);
    final daysDifference = harvestDay.difference(today).inDays;
    final formattedDate = DateFormat('dd MMMM yyyy').format(widget.estimatedHarvestDate!);

    // 🆕 Tambahkan context DAP
    final targetDAP = 100;
    final isMaturityReached = widget.dap >= targetDAP;
    final isGDUReached = widget.gdu >= 1500.0;

    String title;
    String subtitle;
    String additionalInfo;
    IconData icon;
    Color iconColor;
    List<Color> gradientColors;

    // Logika berdasarkan DAP + GDU
    if (isMaturityReached && isGDUReached) {
      // Sudah siap panen (ideal)
      title = '🎉 Siap Panen!';
      subtitle = 'Tanaman telah mencapai masa panen';
      additionalInfo = 'DAP: ${widget.dap} | GDU: ${widget.gdu.toStringAsFixed(0)}°C';
      icon = Icons.celebration;
      iconColor = Colors.green;
      gradientColors = [Colors.green.withAlpha((0.25 * 255).toInt()), Colors.teal.withAlpha((0.15 * 255).toInt())];
    }
    else if (widget.dap >= targetDAP && !isGDUReached) {
      // DAP sudah cukup, tapi GDU kurang (cuaca dingin)
      title = '⚠️ Review Sebelum Panen';
      subtitle = 'DAP sudah ${widget.dap}, tapi GDU belum optimal';
      additionalInfo = 'GDU: ${widget.gdu.toStringAsFixed(0)}°C (target: 1500°C)';
      icon = Icons.warning_amber;
      iconColor = Colors.amber;
      gradientColors = [Colors.amber.withAlpha((0.25 * 255).toInt()), Colors.orange.withAlpha((0.15 * 255).toInt())];
    }
    else if (daysDifference > 0) {
      // Belum waktunya panen
      title = '📅 Estimasi Panen';
      subtitle = daysDifference == 1 ? 'Besok!' : 'Dalam $daysDifference hari lagi';
      additionalInfo = 'Target: DAP $targetDAP | DAP saat ini: ${widget.dap}';
      icon = Icons.calendar_month;
      iconColor = Colors.blue;
      gradientColors = [Colors.blue.withAlpha((0.25 * 255).toInt()), Colors.cyan.withAlpha((0.15 * 255).toInt())];
    }
    else {
      // Sudah lewat estimasi tapi belum dipanen
      title = '🌾 Monitoring Panen';
      subtitle = 'Estimasi panen: $formattedDate';
      additionalInfo = 'Cek kondisi biji sebelum panen';
      icon = Icons.agriculture;
      iconColor = Colors.brown;
      gradientColors = [Colors.brown.withAlpha((0.25 * 255).toInt()), Colors.deepOrange.withAlpha((0.15 * 255).toInt())];
    }

    return Container(
      padding: EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: iconColor.withAlpha((0.4 * 255).toInt()), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: iconColor.withAlpha((0.2 * 255).toInt()),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: iconColor, size: 32),
              ),
              SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold
                    )),
                    SizedBox(height: 6),
                    Text(subtitle, style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14
                    )),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha((0.2 * 255).toInt()),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white60, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    additionalInfo,
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingHarvestCard() {
    return Container(
      padding: EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.06 * 255).toInt()),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha((0.12 * 255).toInt())),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha((0.1 * 255).toInt()),
              borderRadius: BorderRadius.circular(16),
            ),
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white60),
              ),
            ),
          ),
          SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Menghitung Estimasi Panen...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Memproses data GDU dan DAP',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard() {
    final recommendations = _getRecommendations();

    return Container(
      padding: EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.06 * 255).toInt()),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha((0.12 * 255).toInt())),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.yellow[300], size: 20),
              SizedBox(width: 10),
              Text('Rekomendasi', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 16),
          ...recommendations.map((rec) => Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: EdgeInsets.only(top: 2),
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: rec['color'].withAlpha((0.15 * 255).toInt()),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(rec['icon'], color: rec['color'], size: 16),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(rec['title'], style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      SizedBox(height: 4),
                      Text(rec['description'], style: TextStyle(color: Colors.white.withAlpha((0.6 * 255).toInt()), fontSize: 12, height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getRecommendations() {
    // 🆕 Rekomendasi berdasarkan fase DAP
    final phaseInfo = widget.phaseInfoByDAP;
    final phaseName = phaseInfo?['name'] ?? 'Vegetative';

    if (phaseName == 'Vegetative') {
      if (widget.dap < 15) {
        return [
          {
            'icon': Icons.water_drop,
            'color': Colors.blue,
            'title': 'Pemantauan Kelembaban',
            'description': 'Pastikan tanah tetap lembab untuk perkecambahan optimal',
          },
          {
            'icon': Icons.bug_report,
            'color': Colors.orange,
            'title': 'Kontrol Hama Awal',
            'description': 'Lindungi bibit dari hama tanah dan burung',
          },
        ];
      } else {
        return [
          {
            'icon': Icons.grass,
            'color': Colors.green,
            'title': 'Pemupukan Nitrogen',
            'description': 'Fase vegetatif membutuhkan nitrogen tinggi untuk pertumbuhan daun',
          },
          {
            'icon': Icons.opacity,
            'color': Colors.blue,
            'title': 'Irigasi Teratur',
            'description': 'Pertahankan kelembaban tanah 60-80% kapasitas lapang',
          },
        ];
      }
    } else if (phaseName == 'Generative') {
      return [
        {
          'icon': Icons.local_florist,
          'color': Colors.pink,
          'title': 'Fase Kritis Penyerbukan',
          'description': 'Hindari stress air - periode paling sensitif!',
        },
        {
          'icon': Icons.pest_control,
          'color': Colors.red,
          'title': 'Kontrol Hama Intensif',
          'description': 'Waspadai penggerek batang dan ulat daun',
        },
      ];
    } else if (phaseName == 'Pre-Harvest') {
      return [
        {
          'icon': Icons.grain,
          'color': Colors.amber,
          'title': 'Pemupukan Kalium',
          'description': 'Tingkatkan aplikasi kalium untuk pengisian biji optimal',
        },
        {
          'icon': Icons.warning_amber,
          'color': Colors.orange,
          'title': 'Monitoring Penyakit',
          'description': 'Waspada busuk tongkol dan penyakit daun',
        },
      ];
    } else {
      return [
        {
          'icon': Icons.agriculture,
          'color': Colors.brown,
          'title': 'Persiapan Panen',
          'description': 'Siapkan alat dan tenaga untuk panen',
        },
        {
          'icon': Icons.schedule,
          'color': Colors.green,
          'title': 'Monitoring Kadar Air',
          'description': 'Pastikan kadar air biji optimal (20-25%) sebelum panen',
        },
      ];
    }
  }
}

// 🆕 Custom DAP Timeline Painter
class DAPTimelinePainter extends CustomPainter {
  final List<Map<String, dynamic>> phases;
  final int currentDAP;

  DAPTimelinePainter({
    required this.phases,
    required this.currentDAP,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final maxDAP = 100.0;
    final paint = Paint()
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Background line
    paint.color = Colors.white.withAlpha((0.15 * 255).toInt());
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );

    // Progress line
    final progressWidth = (currentDAP / maxDAP * size.width).clamp(0.0, size.width);
    final progressPaint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.green, Colors.green.shade300],
      ).createShader(Rect.fromLTWH(0, size.height / 2 - 2, progressWidth, 4))
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(progressWidth, size.height / 2),
      progressPaint,
    );

    // Phase points
    for (var phase in phases) {
      final dap = (phase['dap'] as int).toDouble();
      final x = (dap / maxDAP * size.width).clamp(0.0, size.width);
      final isActive = dap <= currentDAP;
      final isCurrent = (currentDAP - dap).abs() <= 5; // Current jika dalam range 5 hari

      // Glow for current phase
      if (isCurrent) {
        final glowPaint = Paint()
          ..color = Colors.amber.withAlpha((0.3 * 255).toInt())
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawCircle(Offset(x, size.height / 2), 12, glowPaint);
      }

      // Circle background
      final bgPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.black.withAlpha((0.3 * 255).toInt());
      canvas.drawCircle(Offset(x, size.height / 2), isCurrent ? 10 : 8, bgPaint);

      // Circle
      final circlePaint = Paint()
        ..style = PaintingStyle.fill
        ..color = isCurrent
            ? Colors.amber
            : (isActive ? Colors.green : Colors.white.withAlpha((0.3 * 255).toInt()));
      canvas.drawCircle(Offset(x, size.height / 2), isCurrent ? 8 : 6, circlePaint);

      // Inner dot
      if (isActive && !isCurrent) {
        final innerPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = Colors.white;
        canvas.drawCircle(Offset(x, size.height / 2), 2, innerPaint);
      }

      // Label
      final textPainter = TextPainter(
        text: TextSpan(
          text: phase['label'],
          style: TextStyle(
            color: isCurrent
                ? Colors.amber
                : (isActive ? Colors.white : Colors.white.withAlpha((0.5 * 255).toInt())),
            fontSize: isCurrent ? 12 : 11,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, size.height / 2 + 18),
      );

      // DAP value for current
      if (isCurrent) {
        final dapTextPainter = TextPainter(
          text: TextSpan(
            text: '$currentDAP DAP',
            style: TextStyle(
              color: Colors.amber.shade300,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        );
        dapTextPainter.layout();
        dapTextPainter.paint(
          canvas,
          Offset(x - dapTextPainter.width / 2, size.height / 2 - 22),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Custom Comparison Chart Painter (unchanged)
class ComparisonChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> historicalGDU;
  final double currentGDU;
  final int dap;

  ComparisonChartPainter({
    required this.historicalGDU,
    required this.currentGDU,
    required this.dap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (historicalGDU.isEmpty || dap == 0) return;

    final padding = 40.0;
    final chartWidth = size.width - padding * 2;
    final chartHeight = size.height - padding * 2;
    final maxDays = dap.toDouble();
    final maxGDU = 1500.0;

    // Draw grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withAlpha((0.1 * 255).toInt())
      ..strokeWidth = 1;

    for (var i = 0; i <= 4; i++) {
      final y = padding + (chartHeight * i / 4);
      canvas.drawLine(
        Offset(padding, y),
        Offset(size.width - padding, y),
        gridPaint,
      );

      final gduValue = maxGDU * (1 - i / 4);
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${gduValue.toInt()}',
          style: TextStyle(
            color: Colors.white.withAlpha((0.5 * 255).toInt()),
            fontSize: 10,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(5, y - textPainter.height / 2));
    }

    // Draw ideal line (dashed)
    final idealPaint = Paint()
      ..color = Colors.amber.withAlpha((0.7 * 255).toInt())
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final idealPath = Path();
    idealPath.moveTo(padding, padding + chartHeight);
    idealPath.lineTo(size.width - padding, padding);
    _drawDashedPath(canvas, idealPath, idealPaint, 5, 5);

    // Draw actual line
    final actualPaint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.green, Colors.green.shade300],
      ).createShader(Rect.fromLTWH(padding, padding, chartWidth, chartHeight))
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final actualPath = Path();
    for (var i = 0; i < historicalGDU.length; i++) {
      final data = historicalGDU[i];
      final x = padding + (data['day'] / maxDays * chartWidth);
      final y = padding + chartHeight - (data['gdu'] / maxGDU * chartHeight);

      if (i == 0) {
        actualPath.moveTo(x, y);
      } else {
        actualPath.lineTo(x, y);
      }
    }
    canvas.drawPath(actualPath, actualPaint);

    // Draw gradient under actual line
    final gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.green.withAlpha((0.4 * 255).toInt()),
          Colors.green.withAlpha((0.05 * 255).toInt()),
        ],
      ).createShader(Rect.fromLTWH(padding, padding, chartWidth, chartHeight))
      ..style = PaintingStyle.fill;

    final fillPath = Path.from(actualPath);
    fillPath.lineTo(size.width - padding, padding + chartHeight);
    fillPath.lineTo(padding, padding + chartHeight);
    fillPath.close();
    canvas.drawPath(fillPath, gradientPaint);

    // Draw current point
    final currentX = padding + (dap / maxDays * chartWidth);
    final currentY = padding + chartHeight - (currentGDU / maxGDU * chartHeight);

    final glowPaint = Paint()
      ..color = Colors.green.withAlpha((0.4 * 255).toInt())
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset(currentX, currentY), 8, glowPaint);

    final pointPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(currentX, currentY), 5, pointPaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(currentX, currentY), 3, borderPaint);

    // X-axis labels
    final intervals = 5;
    for (var i = 0; i <= intervals; i++) {
      final day = (maxDays * i / intervals).toInt();
      final x = padding + (chartWidth * i / intervals);

      final textPainter = TextPainter(
        text: TextSpan(
          text: '$day',
          style: TextStyle(
            color: Colors.white.withAlpha((0.5 * 255).toInt()),
            fontSize: 10,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, size.height - 20),
      );
    }

    // X-axis label
    final xLabelPainter = TextPainter(
      text: TextSpan(
        text: 'Hari Setelah Tanam (DAP)',
        style: TextStyle(
          color: Colors.white.withAlpha((0.7 * 255).toInt()),
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    xLabelPainter.layout();
    xLabelPainter.paint(
      canvas,
      Offset(size.width / 2 - xLabelPainter.width / 2, size.height - 8),
    );
  }

  void _drawDashedPath(
      Canvas canvas,
      Path path,
      Paint paint,
      double dashWidth,
      double dashSpace,
      ) {
    final pathMetrics = path.computeMetrics();
    for (var metric in pathMetrics) {
      var distance = 0.0;
      while (distance < metric.length) {
        final nextDistance = distance + dashWidth;
        final extractPath = metric.extractPath(distance, nextDistance);
        canvas.drawPath(extractPath, paint);
        distance = nextDistance + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}