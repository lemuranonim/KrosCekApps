import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../services/got_fet_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';

class _GotFetUi {
  static const navy = Color(0xFF061A44);
  static const green = Color(0xFF009B54);
  static const greenDark = Color(0xFF007A43);
  static const greenPale = Color(0xFFE8F7EF);
  static const surface = Color(0xFFF6F8FB);
  static const line = Color(0xFFE3E8F0);
}

enum _GotFetPage {
  home,
  lotTracking,
  gotPhoto,
  gotInput,
  fetPhoto,
  fetAnalysis,
  fetInput,
  review,
}

enum _FetPointStatus { grown, notGrown, review, notReadable }

class GotFetScreen extends StatefulWidget {
  const GotFetScreen({super.key});

  @override
  State<GotFetScreen> createState() => _GotFetScreenState();
}

class _GotFetScreenState extends State<GotFetScreen> {
  final _gotFetService = GotFetService();
  final _imagePicker = ImagePicker();
  final _dateFormat = DateFormat('dd MMM yyyy');
  final _dateTimeFormat = DateFormat('dd MMM yyyy HH:mm');
  final _gotNoteController = TextEditingController();
  final _fetNoteController = TextEditingController();
  final List<File> _gotEvidencePhotos = [];

  late final List<_GotFetSample> _samples;
  late List<_FetPointStatus> _replicationOne;
  late List<_FetPointStatus> _replicationTwo;

  ActiveSession? _session;
  File? _fetPlotPhoto;
  _GotFetPage _page = _GotFetPage.home;
  int _selectedSampleIndex = 0;
  int _selectedReplication = 1;
  int _reviewSegment = 0;
  bool _isSyncing = false;

  int _gotTotalObserved = 100;
  int _gotOffType = 3;
  int _gotSelfing = 2;
  int _gotMale = 1;
  int _gotSuspicious = 2;

  @override
  void initState() {
    super.initState();
    _loadSession();
    _samples = _seedSamples();
    _replicationOne = _seedFetPoints(
      notGrownIndexes: const [6, 13, 24, 39],
      reviewIndexes: const [17],
    );
    _replicationTwo = _seedFetPoints(
      notGrownIndexes: const [4, 15, 28, 42, 46],
      reviewIndexes: const [],
    );
  }

  @override
  void dispose() {
    _gotNoteController.dispose();
    _fetNoteController.dispose();
    super.dispose();
  }

  _GotFetSample get _selectedSample => _samples[_selectedSampleIndex];

  List<_FetPointStatus> get _currentReplication =>
      _selectedReplication == 1 ? _replicationOne : _replicationTwo;

  int get _gotConfirmedIssueCount => _gotOffType + _gotSelfing + _gotMale;

  bool get _gotCountsValid => _gotConfirmedIssueCount <= _gotTotalObserved;

  int get _gotTrueType =>
      math.max(0, _gotTotalObserved - _gotConfirmedIssueCount);

  double get _gotPurity =>
      _gotTotalObserved == 0 ? 0 : (_gotTrueType / _gotTotalObserved) * 100;

  int get _fetTotalGrown =>
      _countStatus(_replicationOne, _FetPointStatus.grown) +
      _countStatus(_replicationTwo, _FetPointStatus.grown);

  int get _fetTotalNotGrown =>
      _countStatus(_replicationOne, _FetPointStatus.notGrown) +
      _countStatus(_replicationTwo, _FetPointStatus.notGrown);

  int get _fetTotalReview =>
      _countStatus(_replicationOne, _FetPointStatus.review) +
      _countStatus(_replicationTwo, _FetPointStatus.review);

  int get _fetTotalNotReadable =>
      _countStatus(_replicationOne, _FetPointStatus.notReadable) +
      _countStatus(_replicationTwo, _FetPointStatus.notReadable);

  int get _currentReplicationGrown =>
      _countStatus(_currentReplication, _FetPointStatus.grown);

  int get _currentReplicationNotGrown =>
      _countStatus(_currentReplication, _FetPointStatus.notGrown);

  int get _currentReplicationReview =>
      _countStatus(_currentReplication, _FetPointStatus.review);

  int get _currentReplicationNotReadable =>
      _countStatus(_currentReplication, _FetPointStatus.notReadable);

  double get _fetEmergence => (_fetTotalGrown / 100) * 100;

  double get _currentReplicationEmergence =>
      (_currentReplicationGrown / _currentReplication.length) * 100;

  bool get _currentReplicationHasOpenItems =>
      _currentReplicationReview + _currentReplicationNotReadable > 0;

  Future<void> _loadSession() async {
    final session = await SessionManager.instance.getActiveSession();
    if (!mounted) return;
    setState(() => _session = session);
  }

  void _openPage(_GotFetPage page) {
    setState(() => _page = page);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AdvantaColors.deepForest : _GotFetUi.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 66,
        backgroundColor: _GotFetUi.navy,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: _page == _GotFetPage.home
            ? null
            : IconButton(
                tooltip: 'Home Dashboard',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => _openPage(_GotFetPage.home),
              ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _pageTitle,
              style: AdvantaText.brandTitle.copyWith(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _pageSubtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AdvantaText.caption.copyWith(
                color: Colors.white.withAlpha(175),
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'User Settings',
            icon: const Icon(Icons.account_circle_rounded),
            onPressed: () => context.push('/got-fet/settings'),
          ),
        ],
      ),
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: KeyedSubtree(
              key: ValueKey(_page),
              child: _buildCurrentPage(),
            ),
          ),
          if (_isSyncing)
            const Positioned.fill(
              child: _LoadingOverlay(),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: isDark ? AdvantaColors.deepForest : Colors.white,
        indicatorColor: _GotFetUi.greenPale,
        surfaceTintColor: Colors.transparent,
        selectedIndex: _bottomIndex,
        onDestinationSelected: _openBottomDestination,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded),
            label: 'Lot',
          ),
          NavigationDestination(
            icon: Icon(Icons.eco_outlined),
            selectedIcon: Icon(Icons.eco_rounded),
            label: 'GOT',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_on_outlined),
            selectedIcon: Icon(Icons.grid_on_rounded),
            label: 'FET',
          ),
          NavigationDestination(
            icon: Icon(Icons.verified_outlined),
            selectedIcon: Icon(Icons.verified_rounded),
            label: 'Review',
          ),
        ],
      ),
    );
  }

  String get _pageTitle {
    return switch (_page) {
      _GotFetPage.home => 'Digital GOT & FET',
      _GotFetPage.lotTracking => 'Lot Tracking',
      _GotFetPage.gotPhoto => 'GOT Photo',
      _GotFetPage.gotInput => 'GOT - Input Hasil',
      _GotFetPage.fetPhoto => 'FET Plot Scanner',
      _GotFetPage.fetAnalysis => 'Hasil Analisa Plot',
      _GotFetPage.fetInput => 'FET - Input Hasil',
      _GotFetPage.review => 'Review & Status',
    };
  }

  String get _pageSubtitle {
    if (_page == _GotFetPage.home) {
      return _session?.name.trim().isNotEmpty == true
          ? _session!.name
          : 'Traceable. Accurate. Reliable.';
    }

    return '${_selectedSample.lotId} | ${_selectedSample.hybrid}';
  }

  int get _bottomIndex {
    return switch (_page) {
      _GotFetPage.home => 0,
      _GotFetPage.lotTracking => 1,
      _GotFetPage.gotPhoto || _GotFetPage.gotInput => 2,
      _GotFetPage.fetPhoto ||
      _GotFetPage.fetAnalysis ||
      _GotFetPage.fetInput =>
        3,
      _GotFetPage.review => 4,
    };
  }

  void _openBottomDestination(int index) {
    final page = switch (index) {
      0 => _GotFetPage.home,
      1 => _GotFetPage.lotTracking,
      2 => _GotFetPage.gotInput,
      3 => _GotFetPage.fetPhoto,
      _ => _GotFetPage.review,
    };
    _openPage(page);
  }

  Widget _buildCurrentPage() {
    return switch (_page) {
      _GotFetPage.home => _buildHomeDashboard(),
      _GotFetPage.lotTracking => _buildLotTrackingPage(),
      _GotFetPage.gotPhoto => _buildGotPhotoPage(),
      _GotFetPage.gotInput => _buildGotInputPage(),
      _GotFetPage.fetPhoto => _buildFetPhotoPage(),
      _GotFetPage.fetAnalysis => _buildFetAnalysisPage(),
      _GotFetPage.fetInput => _buildFetInputPage(),
      _GotFetPage.review => _buildReviewPage(),
    };
  }

  Widget _buildHomeDashboard() {
    return _PageScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BrandHeader(
            userName: _session?.name,
            selectedSample: _selectedSample,
          ),
          const SizedBox(height: 16),
          Text('Ringkasan Hari Ini', style: _sectionTitle(context)),
          const SizedBox(height: 10),
          _MetricGrid(
            cards: [
              _MetricData(
                'Observasi Due',
                _samples.where((sample) => sample.isOverdue).length.toString(),
                Icons.event_busy_rounded,
                AdvantaColors.error,
              ),
              _MetricData(
                'Belum Dikirim',
                '2',
                Icons.outbox_rounded,
                AdvantaColors.gold,
              ),
              _MetricData(
                'Menunggu Review',
                _samples
                    .where((sample) => sample.status.contains('Review'))
                    .length
                    .toString(),
                Icons.rate_review_rounded,
                AdvantaColors.gold,
              ),
              _MetricData(
                'Selesai',
                _samples
                    .where((sample) => sample.status == 'Approved')
                    .length
                    .toString(),
                Icons.verified_rounded,
                AdvantaColors.success,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text('Menu Utama', style: _sectionTitle(context)),
          const SizedBox(height: 10),
          _buildMainMenuGrid(),
          const SizedBox(height: 18),
          _WorkflowSummary(
            steps: const [
              ('Sample', Icons.description_rounded),
              ('Prepared', Icons.inventory_2_rounded),
              ('Dispatched', Icons.local_shipping_rounded),
              ('Received', Icons.move_to_inbox_rounded),
              ('Planted', Icons.grass_rounded),
              ('Observed', Icons.eco_rounded),
              ('Reviewed', Icons.assignment_turned_in_rounded),
              ('Decision', Icons.verified_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainMenuGrid() {
    final actions = [
      _MenuAction(
        'Lot Tracking',
        'Status resi sample',
        Icons.inventory_2_rounded,
        _GotFetPage.lotTracking,
      ),
      _MenuAction(
        'GOT Photo',
        'Guided capture',
        Icons.center_focus_strong_rounded,
        _GotFetPage.gotPhoto,
      ),
      _MenuAction(
        'GOT Input',
        'Purity result',
        Icons.fact_check_rounded,
        _GotFetPage.gotInput,
      ),
      _MenuAction(
        'FET Scanner',
        'Foto plot 5x10',
        Icons.grid_on_rounded,
        _GotFetPage.fetPhoto,
      ),
      _MenuAction(
        'FET Analisa',
        'Auto count result',
        Icons.analytics_rounded,
        _GotFetPage.fetAnalysis,
      ),
      _MenuAction(
        'FET Input',
        'Final emergence',
        Icons.edit_note_rounded,
        _GotFetPage.fetInput,
      ),
      _MenuAction(
        'Review Status',
        'Approve/revisi',
        Icons.verified_rounded,
        _GotFetPage.review,
      ),
      _MenuAction(
        'Sinkronisasi',
        'Draft lokal',
        Icons.cloud_sync_rounded,
        _GotFetPage.home,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 640 ? 4 : 3;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: columns == 4 ? 1.55 : 0.96,
          ),
          itemBuilder: (context, index) {
            final action = actions[index];
            return _MenuActionCard(
              action: action,
              onTap: () {
                if (action.page == _GotFetPage.home &&
                    action.title == 'Sinkronisasi') {
                  _showSnack('Data tersimpan ke backend saat Submit.');
                  return;
                }
                _openPage(action.page);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildLotTrackingPage() {
    return _PageScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSamplePicker(),
          const SizedBox(height: 12),
          _buildLotSummaryCard(),
          const SizedBox(height: 16),
          _buildTimelineCard(_selectedSample),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.visibility_rounded),
              label: const Text('LIHAT DETAIL'),
              onPressed: () => _openPage(_GotFetPage.review),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGotPhotoPage() {
    return _PageScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSamplePicker(),
          const SizedBox(height: 12),
          _GuidanceBanner(
            text: 'Ikuti panduan untuk foto yang valid',
            color: AdvantaColors.success,
          ),
          const SizedBox(height: 10),
          _CameraMockup(
            mode: _CameraMockupMode.got,
            title: 'Posisikan tanaman di dalam marker',
            footer: 'Auto capture jika semua indikator OK',
          ),
          const SizedBox(height: 12),
          _DualActionBar(
            leftLabel: 'Gallery',
            rightLabel: 'Capture',
            leftIcon: Icons.photo_library_rounded,
            rightIcon: Icons.camera_alt_rounded,
            onLeft: () => _pickGotEvidence(ImageSource.gallery),
            onRight: () => _pickGotEvidence(ImageSource.camera),
          ),
          const SizedBox(height: 12),
          _IndicatorGrid(
            items: const [
              ('Angle', 'OK', Icons.screen_rotation_alt_rounded),
              ('Focus', 'OK', Icons.center_focus_strong_rounded),
              ('Jarak', 'OK', Icons.straighten_rounded),
              ('Cahaya', 'OK', Icons.wb_sunny_rounded),
            ],
          ),
          if (_gotEvidencePhotos.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildPhotoEvidenceRow(),
          ],
        ],
      ),
    );
  }

  Widget _buildGotInputPage() {
    return _PageScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSamplePicker(),
          const SizedBox(height: 12),
          _buildLotIdentityCard(
            extraRows: const [
              ('Plot', 'G1 - U1'),
              ('Stage', 'Flowering'),
            ],
          ),
          const SizedBox(height: 14),
          _buildGotCountForm(),
          const SizedBox(height: 12),
          _buildPhotoEvidenceRow(),
          const SizedBox(height: 12),
          _buildNoteBox(controller: _gotNoteController),
          const SizedBox(height: 16),
          _DualActionBar(
            leftLabel: 'Simpan Draft',
            rightLabel: 'Submit',
            leftIcon: Icons.save_outlined,
            rightIcon: Icons.send_rounded,
            rightEnabled: _gotCountsValid && !_isSyncing,
            onLeft: () => _showSnack('Draft GOT disimpan lokal.'),
            onRight: _submitGotResult,
          ),
        ],
      ),
    );
  }

  Widget _buildFetPhotoPage() {
    return _PageScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSamplePicker(),
          const SizedBox(height: 12),
          _GuidanceBanner(
            text: 'Posisikan seluruh plot 5x10 terfoto jelas',
            color: AdvantaColors.success,
          ),
          const SizedBox(height: 10),
          _buildReplicationSelector(),
          const SizedBox(height: 10),
          _CameraMockup(
            mode: _CameraMockupMode.fet,
            title: 'Sejajarkan plot dengan bingkai',
            footer: '50 titik tanam akan dianalisis otomatis',
          ),
          const SizedBox(height: 12),
          _DualActionBar(
            leftLabel: _fetPlotPhoto == null ? 'Upload' : 'Ganti',
            rightLabel: _fetPlotPhoto == null ? 'Capture' : 'Analisa',
            leftIcon: Icons.photo_library_rounded,
            rightIcon: _fetPlotPhoto == null
                ? Icons.camera_alt_rounded
                : Icons.analytics_rounded,
            onLeft: () => _pickFetPlotPhoto(ImageSource.gallery),
            onRight: _fetPlotPhoto == null
                ? () => _pickFetPlotPhoto(ImageSource.camera)
                : () => _openPage(_GotFetPage.fetAnalysis),
          ),
          if (_fetPlotPhoto != null) ...[
            const SizedBox(height: 12),
            _buildPlotEvidenceCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildFetAnalysisPage() {
    return _PageScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildReplicationSelector(),
          const SizedBox(height: 14),
          _MetricGrid(
            cards: [
              _MetricData('Tumbuh', _currentReplicationGrown.toString(),
                  Icons.check_circle_rounded, AdvantaColors.success),
              _MetricData(
                  'Tidak Tumbuh',
                  _currentReplicationNotGrown.toString(),
                  Icons.cancel_rounded,
                  AdvantaColors.error),
              _MetricData(
                  'Emergence',
                  '${_currentReplicationEmergence.toStringAsFixed(1)}%',
                  Icons.percent_rounded,
                  AdvantaColors.primaryGreen),
              _MetricData('Perlu Review', _currentReplicationReview.toString(),
                  Icons.help_rounded, AdvantaColors.gold),
            ],
          ),
          const SizedBox(height: 16),
          _buildFetGridCard(showLabel: false),
          const SizedBox(height: 12),
          _buildFetLegend(),
          const SizedBox(height: 16),
          _DualActionBar(
            leftLabel: 'Koreksi Manual',
            rightLabel: 'Simpan Hasil',
            leftIcon: Icons.tune_rounded,
            rightIcon: Icons.save_rounded,
            rightEnabled: !_currentReplicationHasOpenItems,
            onLeft: () => _showSnack('Tap titik di grid untuk koreksi manual.'),
            onRight: () => _openPage(_GotFetPage.fetInput),
          ),
        ],
      ),
    );
  }

  Widget _buildFetInputPage() {
    return _PageScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSamplePicker(),
          const SizedBox(height: 12),
          _buildLotIdentityCard(
            extraRows: [
              ('Plot', 'F1 - U1'),
              ('DAP', '7'),
              ('Ulangan', '$_selectedReplication'),
            ],
          ),
          const SizedBox(height: 14),
          _buildFetInputForm(),
          const SizedBox(height: 12),
          _buildPlotEvidenceCard(),
          const SizedBox(height: 12),
          _buildNoteBox(controller: _fetNoteController),
          const SizedBox(height: 16),
          _DualActionBar(
            leftLabel: 'Simpan Draft',
            rightLabel: 'Submit',
            leftIcon: Icons.save_outlined,
            rightIcon: Icons.send_rounded,
            rightEnabled: !_currentReplicationHasOpenItems && !_isSyncing,
            onLeft: () => _showSnack('Draft FET disimpan lokal.'),
            onRight: _submitFetResult,
          ),
        ],
      ),
    );
  }

  Widget _buildReviewPage() {
    return _PageScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment<int>(value: 0, label: Text('GOT')),
              ButtonSegment<int>(value: 1, label: Text('FET')),
            ],
            selected: {_reviewSegment},
            onSelectionChanged: (selection) {
              setState(() => _reviewSegment = selection.first);
            },
          ),
          const SizedBox(height: 12),
          _buildLotIdentityCard(
            extraRows: _reviewSegment == 0
                ? const [
                    ('Plot', 'G1 - U1'),
                    ('Stage', 'Flowering'),
                  ]
                : const [
                    ('Plot', 'F1 - U1'),
                    ('DAP', '7'),
                  ],
          ),
          const SizedBox(height: 14),
          _reviewSegment == 0
              ? _buildGotReviewResult()
              : _buildFetReviewResult(),
          const SizedBox(height: 14),
          _buildReviewTimeline(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSyncing
                      ? null
                      : () => _submitReviewDecision('Rejected'),
                  child: const Text('Tolak'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSyncing
                      ? null
                      : () => _submitReviewDecision('Revision Required'),
                  child: const Text('Revisi'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSyncing
                      ? null
                      : () => _submitReviewDecision('Approved'),
                  child: const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSamplePicker() {
    final theme = Theme.of(context);

    return DropdownButtonFormField<int>(
      key: ValueKey('got-fet-sample-$_selectedSampleIndex'),
      initialValue: _selectedSampleIndex,
      decoration: InputDecoration(
        labelText: 'Lot / Sample',
        prefixIcon: const Icon(Icons.qr_code_2_rounded),
        filled: true,
        fillColor: theme.inputDecorationTheme.fillColor,
      ),
      items: [
        for (var i = 0; i < _samples.length; i++)
          DropdownMenuItem<int>(
            value: i,
            child: Text(
              '${_samples[i].lotId} - ${_samples[i].testType}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (value) {
        if (value == null) return;
        setState(() => _selectedSampleIndex = value);
      },
    );
  }

  Widget _buildLotSummaryCard() {
    final sample = _selectedSample;
    final statusColor = _statusColor(sample.status);
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  sample.lotId,
                  style: AdvantaText.heading2.copyWith(
                    color: _strongTextColor(context),
                  ),
                ),
              ),
              _StatusPill(label: sample.status, color: statusColor),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _MiniFact(label: 'Hybrid', value: sample.hybrid)),
              Expanded(
                  child: _MiniFact(label: 'Test Type', value: sample.testType)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _MiniFact(label: 'PIC', value: sample.pic)),
              Expanded(
                  child: _MiniFact(
                      label: 'Due', value: _dateFormat.format(sample.dueDate))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLotIdentityCard({
    required List<(String, String)> extraRows,
  }) {
    final rows = [
      ('Lot ID', _selectedSample.lotId),
      ('Hybrid', _selectedSample.hybrid),
      ...extraRows,
    ];

    return _PanelCard(
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _InfoRow(label: rows[i].$1, value: rows[i].$2),
            if (i != rows.length - 1) const SizedBox(height: 9),
          ],
        ],
      ),
    );
  }

  Widget _buildTimelineCard(_GotFetSample sample) {
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Status Pengiriman',
              style: AdvantaText.heading3.copyWith(
                color: _strongTextColor(context),
              )),
          const SizedBox(height: 14),
          for (var i = 0; i < sample.steps.length; i++)
            _TimelineRow(
              step: sample.steps[i],
              isLast: i == sample.steps.length - 1,
              dateTimeFormat: _dateTimeFormat,
            ),
        ],
      ),
    );
  }

  Widget _buildGotCountForm() {
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hasil Pengamatan',
              style: AdvantaText.heading3.copyWith(
                color: _strongTextColor(context),
              )),
          const SizedBox(height: 12),
          _CounterRow(
            label: 'Total Tanaman Diamati',
            value: _gotTotalObserved,
            onAdd: () => _adjustGotCount('total', 1),
            onRemove: () => _adjustGotCount('total', -1),
          ),
          _CounterRow(
            label: 'Off-type',
            value: _gotOffType,
            onAdd: () => _adjustGotCount('offType', 1),
            onRemove: () => _adjustGotCount('offType', -1),
          ),
          _CounterRow(
            label: 'Selfing',
            value: _gotSelfing,
            onAdd: () => _adjustGotCount('selfing', 1),
            onRemove: () => _adjustGotCount('selfing', -1),
          ),
          _CounterRow(
            label: 'Male',
            value: _gotMale,
            onAdd: () => _adjustGotCount('male', 1),
            onRemove: () => _adjustGotCount('male', -1),
          ),
          _CounterRow(
            label: 'Tanaman Meragukan',
            value: _gotSuspicious,
            onAdd: () => _adjustGotCount('suspicious', 1),
            onRemove: () => _adjustGotCount('suspicious', -1),
          ),
          const Divider(height: 26),
          _InfoRow(
            label: 'Purity (%)',
            value: _gotCountsValid ? _gotPurity.toStringAsFixed(2) : 'Invalid',
            valueColor:
                _gotCountsValid ? AdvantaColors.success : AdvantaColors.error,
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoEvidenceRow() {
    final previewPhotos = _gotEvidencePhotos.take(3).toList();
    final emptySlots = math.max(0, 3 - previewPhotos.length);

    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Foto Evidence',
              style: AdvantaText.heading3.copyWith(
                color: _strongTextColor(context),
              )),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < previewPhotos.length; i++) ...[
                Expanded(
                  child: _EvidencePhotoThumb(
                    file: previewPhotos[i],
                    onRemove: () => _removeGotEvidence(previewPhotos[i]),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              for (var i = 0; i < emptySlots; i++) ...[
                const Expanded(child: _PhotoThumb()),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showEvidenceSourceSheet(
                    onCamera: () => _pickGotEvidence(ImageSource.camera),
                    onGallery: () => _pickGotEvidence(ImageSource.gallery),
                  ),
                  child: const Icon(Icons.add_rounded),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoteBox({
    required TextEditingController controller,
  }) {
    return TextField(
      controller: controller,
      maxLines: 2,
      decoration: InputDecoration(
        labelText: 'Catatan',
        hintText: 'Tulis catatan optional',
        prefixIcon: const Icon(Icons.notes_rounded),
        filled: true,
        fillColor: Theme.of(context).inputDecorationTheme.fillColor,
      ),
    );
  }

  Widget _buildReplicationSelector() {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<int>(
        segments: const [
          ButtonSegment<int>(
            value: 1,
            label: Text('Ulangan 1'),
          ),
          ButtonSegment<int>(
            value: 2,
            label: Text('Ulangan 2'),
          ),
        ],
        selected: {_selectedReplication},
        onSelectionChanged: (selection) {
          setState(() => _selectedReplication = selection.first);
        },
      ),
    );
  }

  Widget _buildFetGridCard({bool showLabel = true}) {
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showLabel) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Visual Grid 5 x 10',
                    style: AdvantaText.heading3.copyWith(
                      color: _strongTextColor(context),
                    ),
                  ),
                ),
                Text('50 titik', style: _mutedTextStyle(context)),
              ],
            ),
            const SizedBox(height: 12),
          ],
          _FetPointGrid(
            points: _currentReplication,
            statusColor: _fetStatusColor,
            statusLabel: _fetStatusShortLabel,
            onTap: _cycleFetPoint,
          ),
          const SizedBox(height: 10),
          Text(
            'Tap titik untuk koreksi status sebelum hasil disimpan.',
            style: _mutedTextStyle(context),
          ),
        ],
      ),
    );
  }

  Widget _buildFetLegend() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final status in _FetPointStatus.values)
          _LegendChip(
            label: _fetStatusLabel(status),
            color: _fetStatusColor(status),
          ),
      ],
    );
  }

  Widget _buildFetInputForm() {
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hasil Ulangan $_selectedReplication',
              style: AdvantaText.heading3.copyWith(
                color: _strongTextColor(context),
              )),
          const SizedBox(height: 12),
          _InfoRow(label: 'Total Titik Tanam', value: '50'),
          const SizedBox(height: 9),
          _InfoRow(label: 'Tumbuh', value: _currentReplicationGrown.toString()),
          const SizedBox(height: 9),
          _InfoRow(
              label: 'Tidak Tumbuh',
              value: _currentReplicationNotGrown.toString()),
          const SizedBox(height: 9),
          _InfoRow(
            label: 'Emergence (%)',
            value: _currentReplicationEmergence.toStringAsFixed(2),
            valueColor: AdvantaColors.success,
          ),
        ],
      ),
    );
  }

  Widget _buildPlotEvidenceCard() {
    return _PanelCard(
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: AspectRatio(
              aspectRatio: 1.45,
              child: _fetPlotPhoto == null
                  ? const _PlotPreview()
                  : _PlotPhotoPreview(file: _fetPlotPhoto!),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              icon: Icon(
                _fetPlotPhoto == null
                    ? Icons.add_rounded
                    : Icons.photo_library_rounded,
              ),
              label: Text(_fetPlotPhoto == null ? 'Tambah Foto' : 'Ganti Foto'),
              onPressed: () => _showEvidenceSourceSheet(
                onCamera: () => _pickFetPlotPhoto(ImageSource.camera),
                onGallery: () => _pickFetPlotPhoto(ImageSource.gallery),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGotReviewResult() {
    return _PanelCard(
      child: Column(
        children: [
          _InfoRow(label: 'Total Tanaman Diamati', value: '$_gotTotalObserved'),
          const SizedBox(height: 8),
          _InfoRow(label: 'Off-type', value: '$_gotOffType'),
          const SizedBox(height: 8),
          _InfoRow(label: 'Selfing', value: '$_gotSelfing'),
          const SizedBox(height: 8),
          _InfoRow(label: 'Male', value: '$_gotMale'),
          const SizedBox(height: 8),
          _InfoRow(label: 'Tanaman Meragukan', value: '$_gotSuspicious'),
          const SizedBox(height: 8),
          _InfoRow(
            label: 'Purity (%)',
            value: _gotPurity.toStringAsFixed(2),
            valueColor: AdvantaColors.success,
          ),
          const SizedBox(height: 12),
          _buildPhotoEvidenceRow(),
        ],
      ),
    );
  }

  Widget _buildFetReviewResult() {
    return _PanelCard(
      child: Column(
        children: [
          _InfoRow(label: 'Total Titik Tanam', value: '100'),
          const SizedBox(height: 8),
          _InfoRow(label: 'Tumbuh', value: '$_fetTotalGrown'),
          const SizedBox(height: 8),
          _InfoRow(label: 'Tidak Tumbuh', value: '$_fetTotalNotGrown'),
          const SizedBox(height: 8),
          _InfoRow(label: 'Review', value: '$_fetTotalReview'),
          const SizedBox(height: 8),
          _InfoRow(label: 'Tidak Terbaca', value: '$_fetTotalNotReadable'),
          const SizedBox(height: 8),
          _InfoRow(
            label: 'Emergence (%)',
            value: _fetEmergence.toStringAsFixed(2),
            valueColor: AdvantaColors.success,
          ),
        ],
      ),
    );
  }

  Widget _buildReviewTimeline() {
    final events = [
      ('Draft', DateTime(2026, 5, 20, 8, 0), true),
      ('Submitted', DateTime(2026, 5, 20, 9, 15), true),
      ('In Review', DateTime(2026, 5, 20, 10, 20), true),
      ('Approved', DateTime(2026, 5, 20, 12, 0), false),
      ('Final', DateTime(2026, 5, 20, 14, 0), false),
    ];

    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Riwayat Status',
              style: AdvantaText.heading3.copyWith(
                color: _strongTextColor(context),
              )),
          const SizedBox(height: 12),
          for (var i = 0; i < events.length; i++)
            _TimelineRow(
              step: _TrackingStep(events[i].$1, events[i].$2, events[i].$3),
              isLast: i == events.length - 1,
              dateTimeFormat: _dateTimeFormat,
            ),
        ],
      ),
    );
  }

  void _adjustGotCount(String field, int delta) {
    setState(() {
      switch (field) {
        case 'total':
          _gotTotalObserved = math.max(0, _gotTotalObserved + delta);
          _gotOffType = math.min(_gotOffType, _gotTotalObserved);
          _gotSelfing = math.min(_gotSelfing, _gotTotalObserved);
          _gotMale = math.min(_gotMale, _gotTotalObserved);
          _gotSuspicious = math.min(_gotSuspicious, _gotTotalObserved);
          break;
        case 'offType':
          _gotOffType = _boundedCount(_gotOffType + delta);
          break;
        case 'selfing':
          _gotSelfing = _boundedCount(_gotSelfing + delta);
          break;
        case 'male':
          _gotMale = _boundedCount(_gotMale + delta);
          break;
        case 'suspicious':
          _gotSuspicious = _boundedCount(_gotSuspicious + delta);
          break;
      }
    });
  }

  int _boundedCount(int value) => value.clamp(0, _gotTotalObserved).toInt();

  void _cycleFetPoint(int index) {
    final current = _currentReplication[index];
    final next = switch (current) {
      _FetPointStatus.grown => _FetPointStatus.notGrown,
      _FetPointStatus.notGrown => _FetPointStatus.review,
      _FetPointStatus.review => _FetPointStatus.notReadable,
      _FetPointStatus.notReadable => _FetPointStatus.grown,
    };

    setState(() => _currentReplication[index] = next);
  }

  Future<void> _pickGotEvidence(ImageSource source) async {
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 86,
        maxWidth: 1800,
      );
      if (image == null || !mounted) return;
      setState(() => _gotEvidencePhotos.add(File(image.path)));
      _showSnack('Foto evidence GOT ditambahkan.');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Gagal mengambil foto GOT: ${_friendlyError(e)}');
    }
  }

  Future<void> _pickFetPlotPhoto(ImageSource source) async {
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 2200,
      );
      if (image == null || !mounted) return;
      setState(() => _fetPlotPhoto = File(image.path));
      _showSnack('Foto plot FET siap dianalisis.');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Gagal mengambil foto FET: ${_friendlyError(e)}');
    }
  }

  void _removeGotEvidence(File file) {
    setState(() => _gotEvidencePhotos.remove(file));
  }

  Future<void> _submitGotResult() async {
    if (!_gotCountsValid) {
      _showSnack('Jumlah off-type, selfing, dan male melebihi total tanaman.');
      return;
    }

    await _runBackendAction(
      successMessage: 'GOT result ${_selectedSample.lotId} submitted.',
      action: () async {
        await _gotFetService.submitGotObservation(
          lotId: _selectedSample.lotId,
          sampleId: _selectedSample.sampleId,
          hybrid: _selectedSample.hybrid,
          plotId: 'G1 - U1',
          stage: 'Flowering',
          totalObserved: _gotTotalObserved,
          offTypeCount: _gotOffType,
          selfingCount: _gotSelfing,
          maleCount: _gotMale,
          suspiciousCount: _gotSuspicious,
          trueTypeCount: _gotTrueType,
          purityPercent: _gotPurity,
          submittedBy: _actorName,
          evidencePhotos: List<File>.from(_gotEvidencePhotos),
          remarks: _optionalText(_gotNoteController),
        );
        if (!mounted) return;
        setState(() => _selectedSample.status = 'Submitted');
      },
    );
  }

  Future<void> _submitFetResult() async {
    if (_currentReplicationHasOpenItems) {
      _showSnack('Selesaikan titik review/tidak terbaca sebelum submit.');
      return;
    }

    await _runBackendAction(
      successMessage: 'FET result ${_selectedSample.lotId} submitted.',
      action: () async {
        await _gotFetService.submitFetObservation(
          lotId: _selectedSample.lotId,
          sampleId: _selectedSample.sampleId,
          hybrid: _selectedSample.hybrid,
          plotId: 'F1 - U1',
          replication: _selectedReplication,
          dap: 7,
          totalPoints: _currentReplication.length,
          grownCount: _currentReplicationGrown,
          notGrownCount: _currentReplicationNotGrown,
          reviewCount: _currentReplicationReview,
          notReadableCount: _currentReplicationNotReadable,
          emergencePercent: _currentReplicationEmergence,
          pointStatuses: [
            for (final point in _currentReplication) _fetStatusPayload(point),
          ],
          submittedBy: _actorName,
          plotPhoto: _fetPlotPhoto,
          remarks: _optionalText(_fetNoteController),
        );
        if (!mounted) return;
        setState(() => _selectedSample.status = 'Submitted');
      },
    );
  }

  Future<void> _submitReviewDecision(String status) async {
    final previousStatus = _selectedSample.status;
    final module = _reviewSegment == 0 ? 'GOT' : 'FET';

    await _runBackendAction(
      successMessage: 'Decision ${_selectedSample.lotId}: $status',
      action: () async {
        await _gotFetService.submitReviewDecision(
          lotId: _selectedSample.lotId,
          sampleId: _selectedSample.sampleId,
          module: module,
          previousStatus: previousStatus,
          newStatus: status,
          reviewer: _actorName,
          remarks: 'Decision from GOT & FET review screen',
        );
        if (!mounted) return;
        setState(() => _selectedSample.status = status);
      },
    );
  }

  Future<void> _runBackendAction({
    required String successMessage,
    required Future<void> Function() action,
  }) async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);

    try {
      await action();
      if (!mounted) return;
      _showSnack(successMessage);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Gagal sinkronisasi: ${_friendlyError(e)}');
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _showEvidenceSourceSheet({
    required VoidCallback onCamera,
    required VoidCallback onGallery,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt_rounded),
                  title: const Text('Ambil dari Kamera'),
                  onTap: () {
                    Navigator.pop(ctx);
                    onCamera();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded),
                  title: const Text('Pilih dari Gallery'),
                  onTap: () {
                    Navigator.pop(ctx);
                    onGallery();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String get _actorName {
    final name = _session?.name.trim();
    if (name != null && name.isNotEmpty) return name;
    final email = _session?.email.trim();
    if (email != null && email.isNotEmpty) return email;
    return 'GOT & FET User';
  }

  String? _optionalText(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  String _friendlyError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    if (message.length <= 140) return message;
    return '${message.substring(0, 140)}...';
  }

  int _countStatus(List<_FetPointStatus> points, _FetPointStatus status) {
    return points.where((point) => point == status).length;
  }

  String _fetStatusPayload(_FetPointStatus status) {
    return switch (status) {
      _FetPointStatus.grown => 'grown',
      _FetPointStatus.notGrown => 'not_grown',
      _FetPointStatus.review => 'review',
      _FetPointStatus.notReadable => 'not_readable',
    };
  }

  Color _fetStatusColor(_FetPointStatus status) {
    return switch (status) {
      _FetPointStatus.grown => AdvantaColors.success,
      _FetPointStatus.notGrown => AdvantaColors.error,
      _FetPointStatus.review => AdvantaColors.gold,
      _FetPointStatus.notReadable => AdvantaColors.mutedGrey,
    };
  }

  String _fetStatusLabel(_FetPointStatus status) {
    return switch (status) {
      _FetPointStatus.grown => 'Tumbuh',
      _FetPointStatus.notGrown => 'Tidak Tumbuh',
      _FetPointStatus.review => 'Titik Terbaca',
      _FetPointStatus.notReadable => 'Tidak Terbaca',
    };
  }

  String _fetStatusShortLabel(_FetPointStatus status) {
    return switch (status) {
      _FetPointStatus.grown => 'G',
      _FetPointStatus.notGrown => 'NG',
      _FetPointStatus.review => 'R',
      _FetPointStatus.notReadable => 'NR',
    };
  }

  Color _statusColor(String status) {
    final normalized = status.toLowerCase();
    if (normalized.contains('approved')) return AdvantaColors.success;
    if (normalized.contains('hold') || normalized.contains('revision')) {
      return AdvantaColors.gold;
    }
    if (normalized.contains('reject') || normalized.contains('overdue')) {
      return AdvantaColors.error;
    }
    if (normalized.contains('review')) return AdvantaColors.gold;
    if (normalized.contains('submit')) return AdvantaColors.primaryGreen;
    return AdvantaColors.mutedGrey;
  }

  TextStyle _sectionTitle(BuildContext context) {
    return AdvantaText.heading3.copyWith(color: _strongTextColor(context));
  }

  TextStyle _mutedTextStyle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AdvantaText.caption.copyWith(
      color: isDark
          ? AdvantaColors.goldLight.withAlpha(155)
          : AdvantaColors.mutedGrey,
    );
  }

  Color _strongTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AdvantaColors.goldLight
        : AdvantaColors.deepForest;
  }

  List<_GotFetSample> _seedSamples() {
    return [
      _GotFetSample(
        lotId: 'KC25-05-0001',
        sampleId: 'GOTFET-001',
        hybrid: 'KC 888',
        crop: 'Field Corn',
        season: 'DS 2026',
        testType: 'GOT + FET',
        status: 'In Review',
        pic: 'QA Field Inspector',
        dueDate: DateTime(2026, 5, 24),
        steps: [
          _TrackingStep('Sample Created', DateTime(2026, 5, 18, 9, 0), true),
          _TrackingStep('Prepared', DateTime(2026, 5, 18, 14, 30), true),
          _TrackingStep('Dispatched', DateTime(2026, 5, 19, 8, 45), true),
          _TrackingStep('In Transit', DateTime(2026, 5, 19, 9, 10), true),
          _TrackingStep('Received', DateTime(2026, 5, 19, 15, 40), false),
          _TrackingStep('Planted', DateTime(2026, 5, 20, 7, 0), false),
          _TrackingStep('Observed', DateTime(2026, 5, 21, 8, 30), false),
          _TrackingStep('Reviewed', DateTime(2026, 5, 22, 10, 0), false),
          _TrackingStep('Completed', DateTime(2026, 5, 22, 14, 0), false),
        ],
      ),
      _GotFetSample(
        lotId: 'KC25-05-0002',
        sampleId: 'FET-045',
        hybrid: 'KC 889',
        crop: 'Sweet Corn',
        season: 'DS 2026',
        testType: 'FET',
        status: 'Observation Due',
        pic: 'Observer B',
        dueDate: DateTime(2026, 5, 20),
        steps: [
          _TrackingStep('Sample Created', DateTime(2026, 5, 9, 9, 0), true),
          _TrackingStep('Prepared', DateTime(2026, 5, 10, 9, 0), true),
          _TrackingStep('Dispatched', DateTime(2026, 5, 10, 13, 0), true),
          _TrackingStep('Received', DateTime(2026, 5, 11, 8, 20), true),
          _TrackingStep('Planted', DateTime(2026, 5, 12, 7, 0), true),
          _TrackingStep('Observed', DateTime(2026, 5, 20, 8, 0), false),
          _TrackingStep('Reviewed', DateTime(2026, 5, 21, 10, 0), false),
          _TrackingStep('Completed', DateTime(2026, 5, 22, 11, 0), false),
        ],
      ),
      _GotFetSample(
        lotId: 'KC25-05-0003',
        sampleId: 'GOT-140',
        hybrid: 'KC 777',
        crop: 'Field Corn',
        season: 'DS 2026',
        testType: 'GOT',
        status: 'In Transit',
        pic: 'GOT Site A',
        dueDate: DateTime(2026, 5, 28),
        steps: [
          _TrackingStep('Sample Created', DateTime(2026, 5, 18, 11, 0), true),
          _TrackingStep('Prepared', DateTime(2026, 5, 19, 9, 0), true),
          _TrackingStep('Dispatched', DateTime(2026, 5, 20, 8, 15), true),
          _TrackingStep('In Transit', DateTime(2026, 5, 20, 10, 0), true),
          _TrackingStep('Received', DateTime(2026, 5, 21, 8, 0), false),
          _TrackingStep('Planted', DateTime(2026, 5, 23, 7, 0), false),
          _TrackingStep('Observed', DateTime(2026, 5, 28, 8, 0), false),
          _TrackingStep('Completed', DateTime(2026, 5, 30, 15, 0), false),
        ],
      ),
    ];
  }

  List<_FetPointStatus> _seedFetPoints({
    required List<int> notGrownIndexes,
    required List<int> reviewIndexes,
  }) {
    return List<_FetPointStatus>.generate(50, (index) {
      if (notGrownIndexes.contains(index)) return _FetPointStatus.notGrown;
      if (reviewIndexes.contains(index)) return _FetPointStatus.review;
      return _FetPointStatus.grown;
    });
  }
}

class _PageScaffold extends StatelessWidget {
  final Widget child;

  const _PageScaffold({required this.child});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [child],
      ),
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black45,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: 12),
              Text(
                'Menyimpan...',
                style: AdvantaText.bodyBold.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  final String? userName;
  final _GotFetSample selectedSample;

  const _BrandHeader({
    required this.userName,
    required this.selectedSample,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AdvantaColors.deepForest : _GotFetUi.navy;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _GotFetUi.navy.withAlpha(isDark ? 60 : 34),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(10),
                child: SvgPicture.asset(
                  'assets/logo_kc.svg',
                  placeholderBuilder: (_) => const Icon(
                    Icons.fact_check_rounded,
                    color: _GotFetUi.navy,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KrosCek',
                      style: AdvantaText.heading2.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      userName?.trim().isNotEmpty == true
                          ? 'Selamat pagi, $userName'
                          : 'Traceable. Accurate. Reliable.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AdvantaText.caption.copyWith(
                        color: Colors.white.withAlpha(180),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.notifications_none_rounded, color: Colors.white),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Digital GOT & FET',
            style: AdvantaText.display.copyWith(
              color: Colors.white,
              fontSize: 30,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Active lot: ${selectedSample.lotId} | ${selectedSample.status}',
            style: AdvantaText.body2.copyWith(
              color: const Color(0xFF55D98B),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _GotFetSample {
  final String lotId;
  final String sampleId;
  final String hybrid;
  final String crop;
  final String season;
  final String testType;
  final String pic;
  final DateTime dueDate;
  final List<_TrackingStep> steps;
  String status;

  _GotFetSample({
    required this.lotId,
    required this.sampleId,
    required this.hybrid,
    required this.crop,
    required this.season,
    required this.testType,
    required this.status,
    required this.pic,
    required this.dueDate,
    required this.steps,
  });

  bool get isOverdue {
    final today = DateTime.now();
    final currentDay = DateTime(today.year, today.month, today.day);
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return dueDay.isBefore(currentDay) &&
        status != 'Approved' &&
        status != 'Completed';
  }
}

class _TrackingStep {
  final String label;
  final DateTime date;
  final bool done;

  const _TrackingStep(this.label, this.date, this.done);
}

class _MetricData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricData(this.label, this.value, this.icon, this.color);
}

class _MenuAction {
  final String title;
  final String subtitle;
  final IconData icon;
  final _GotFetPage page;

  const _MenuAction(this.title, this.subtitle, this.icon, this.page);
}

class _PanelCard extends StatelessWidget {
  final Widget child;

  const _PanelCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AdvantaColors.midGreen : Colors.white,
        borderRadius: AdvantaRadius.cardRadius,
        border: Border.all(
          color:
              isDark ? AdvantaColors.goldLight.withAlpha(36) : _GotFetUi.line,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: _GotFetUi.navy.withAlpha(10),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: child,
    );
  }
}

class _MetricGrid extends StatelessWidget {
  final List<_MetricData> cards;

  const _MetricGrid({required this.cards});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 640 ? 4 : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: crossAxisCount == 4 ? 2.15 : 1.55,
          children: [
            for (final card in cards) _MetricCard(data: card),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final _MetricData data;

  const _MetricCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AdvantaColors.midGreen : Colors.white,
        borderRadius: AdvantaRadius.cardRadius,
        border: Border.all(
          color:
              isDark ? AdvantaColors.goldLight.withAlpha(36) : _GotFetUi.line,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: _GotFetUi.navy.withAlpha(9),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(data.icon, color: data.color, size: 22),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  data.value,
                  maxLines: 1,
                  style: AdvantaText.heading2.copyWith(
                    color: isDark ? AdvantaColors.goldLight : data.color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AdvantaText.caption.copyWith(
                  color: isDark
                      ? AdvantaColors.goldLight.withAlpha(155)
                      : AdvantaColors.mutedGrey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MenuActionCard extends StatelessWidget {
  final _MenuAction action;
  final VoidCallback onTap;

  const _MenuActionCard({
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? AdvantaColors.midGreen : Colors.white,
      borderRadius: AdvantaRadius.cardRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AdvantaRadius.cardRadius,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: AdvantaRadius.cardRadius,
            border: Border.all(
              color: isDark
                  ? AdvantaColors.goldLight.withAlpha(36)
                  : _GotFetUi.line,
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: _GotFetUi.navy.withAlpha(8),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _GotFetUi.green.withAlpha(isDark ? 65 : 22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  action.icon,
                  color: isDark ? AdvantaColors.goldLight : _GotFetUi.greenDark,
                ),
              ),
              const Spacer(),
              Text(
                action.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AdvantaText.bodyBold.copyWith(
                  color: isDark ? AdvantaColors.goldLight : _GotFetUi.navy,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                action.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AdvantaText.caption.copyWith(
                  color: isDark
                      ? AdvantaColors.goldLight.withAlpha(150)
                      : AdvantaColors.mutedGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkflowSummary extends StatelessWidget {
  final List<(String, IconData)> steps;

  const _WorkflowSummary({required this.steps});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Workflow Summary',
            style: AdvantaText.heading3.copyWith(
              color:
                  isDark ? AdvantaColors.goldLight : AdvantaColors.deepForest,
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < steps.length; i++) ...[
                  _WorkflowNode(label: steps[i].$1, icon: steps[i].$2),
                  if (i != steps.length - 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: isDark
                            ? AdvantaColors.goldLight.withAlpha(150)
                            : AdvantaColors.deepForest,
                        size: 18,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkflowNode extends StatelessWidget {
  final String label;
  final IconData icon;

  const _WorkflowNode({
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 74,
      child: Column(
        children: [
          Icon(
            icon,
            color: isDark ? AdvantaColors.goldLight : const Color(0xFF061A44),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AdvantaText.caption.copyWith(
              color:
                  isDark ? AdvantaColors.goldLight : AdvantaColors.deepForest,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _GuidanceBanner extends StatelessWidget {
  final String text;
  final Color color;

  const _GuidanceBanner({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(isDark ? 60 : 28),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(isDark ? 100 : 70)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AdvantaText.bodyBold.copyWith(
          color: isDark ? AdvantaColors.goldLight : _GotFetUi.greenDark,
        ),
      ),
    );
  }
}

enum _CameraMockupMode { got, fet }

class _CameraMockup extends StatelessWidget {
  final _CameraMockupMode mode;
  final String title;
  final String footer;

  const _CameraMockup({
    required this.mode,
    required this.title,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 420,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(48),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: mode == _CameraMockupMode.got
                  ? _GotPlantPainter()
                  : _PlotFieldPainter(),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: mode == _CameraMockupMode.got
                  ? const _CameraMarkerFrame()
                  : const _PlotMarkerFrame(),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 88,
            child: _GuidanceBanner(text: title, color: AdvantaColors.success),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 18,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _CameraButton(icon: Icons.close_rounded),
                _CameraButton(icon: Icons.camera_alt_rounded, primary: true),
                _CameraButton(
                  icon: mode == _CameraMockupMode.got
                      ? Icons.help_outline_rounded
                      : Icons.flashlight_on_rounded,
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 68,
            child: Text(
              footer,
              textAlign: TextAlign.center,
              style: AdvantaText.caption.copyWith(
                color: Colors.white.withAlpha(210),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraButton extends StatelessWidget {
  final IconData icon;
  final bool primary;

  const _CameraButton({
    required this.icon,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: primary ? 58 : 46,
      height: primary ? 58 : 46,
      decoration: BoxDecoration(
        color: primary ? _GotFetUi.green : Colors.black.withAlpha(150),
        shape: BoxShape.circle,
        border: Border.all(
          color: primary ? Colors.white : Colors.white.withAlpha(55),
          width: primary ? 2 : 1,
        ),
      ),
      child: Icon(icon, color: Colors.white),
    );
  }
}

class _CameraMarkerFrame extends StatelessWidget {
  const _CameraMarkerFrame();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _MarkerFramePainter(showCenter: true));
  }
}

class _PlotMarkerFrame extends StatelessWidget {
  const _PlotMarkerFrame();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _MarkerFramePainter(showGrid: true));
  }
}

class _IndicatorGrid extends StatelessWidget {
  final List<(String, String, IconData)> items;

  const _IndicatorGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 640 ? 4 : 2;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.4,
          children: [
            for (final item in items)
              _IndicatorChip(label: item.$1, value: item.$2, icon: item.$3),
          ],
        );
      },
    );
  }
}

class _IndicatorChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _IndicatorChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AdvantaColors.success.withAlpha(isDark ? 45 : 22),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: AdvantaColors.success, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label\n$value',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AdvantaText.caption.copyWith(
                color:
                    isDark ? AdvantaColors.goldLight : AdvantaColors.deepForest,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AdvantaText.body2.copyWith(
              color: isDark
                  ? AdvantaColors.goldLight.withAlpha(165)
                  : AdvantaColors.mutedGrey,
            ),
          ),
        ),
        Text(
          value,
          style: AdvantaText.bodyBold.copyWith(
            color: valueColor ??
                (isDark ? AdvantaColors.goldLight : AdvantaColors.deepForest),
          ),
        ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final _TrackingStep step;
  final bool isLast;
  final DateFormat dateTimeFormat;

  const _TimelineRow({
    required this.step,
    required this.isLast,
    required this.dateTimeFormat,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = step.done ? AdvantaColors.success : AdvantaColors.mutedGrey;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  step.done ? Icons.check_rounded : Icons.more_horiz_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: color.withAlpha(95),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      step.label,
                      style: AdvantaText.bodyBold.copyWith(
                        color: isDark
                            ? AdvantaColors.goldLight
                            : AdvantaColors.deepForest,
                      ),
                    ),
                  ),
                  Text(
                    dateTimeFormat.format(step.date),
                    style: AdvantaText.caption.copyWith(
                      color: isDark
                          ? AdvantaColors.goldLight.withAlpha(155)
                          : AdvantaColors.mutedGrey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(isDark ? 50 : 24),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AdvantaText.caption.copyWith(
          color: isDark ? AdvantaColors.goldLight : color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MiniFact extends StatelessWidget {
  final String label;
  final String value;

  const _MiniFact({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AdvantaText.caption.copyWith(
            color: isDark
                ? AdvantaColors.goldLight.withAlpha(145)
                : AdvantaColors.mutedGrey,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AdvantaText.bodyBold.copyWith(
            color: isDark ? AdvantaColors.goldLight : AdvantaColors.deepForest,
          ),
        ),
      ],
    );
  }
}

class _CounterRow extends StatelessWidget {
  final String label;
  final int value;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _CounterRow({
    required this.label,
    required this.value,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AdvantaText.body2.copyWith(
                color:
                    isDark ? AdvantaColors.goldLight : AdvantaColors.deepForest,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Kurangi $label',
            onPressed: onRemove,
            icon: const Icon(Icons.remove_rounded),
          ),
          SizedBox(
            width: 48,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: AdvantaText.bodyBold.copyWith(
                color:
                    isDark ? AdvantaColors.goldLight : AdvantaColors.deepForest,
              ),
            ),
          ),
          IconButton.filled(
            tooltip: 'Tambah $label',
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            style: IconButton.styleFrom(
              backgroundColor: _GotFetUi.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _DualActionBar extends StatelessWidget {
  final String leftLabel;
  final String rightLabel;
  final IconData leftIcon;
  final IconData rightIcon;
  final bool rightEnabled;
  final VoidCallback onLeft;
  final VoidCallback onRight;

  const _DualActionBar({
    required this.leftLabel,
    required this.rightLabel,
    required this.leftIcon,
    required this.rightIcon,
    required this.onLeft,
    required this.onRight,
    this.rightEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: Icon(leftIcon),
            label: Text(leftLabel),
            onPressed: onLeft,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _GotFetUi.green,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _GotFetUi.line,
              disabledForegroundColor: _GotFetUi.navy.withAlpha(95),
            ),
            icon: Icon(rightIcon),
            label: Text(rightLabel),
            onPressed: rightEnabled ? onRight : null,
          ),
        ),
      ],
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF14210D),
          borderRadius: BorderRadius.circular(10),
        ),
        child: CustomPaint(painter: _MiniPlantPainter()),
      ),
    );
  }
}

class _EvidencePhotoThumb extends StatelessWidget {
  final File file;
  final VoidCallback onRemove;

  const _EvidencePhotoThumb({
    required this.file,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(file, fit: BoxFit.cover),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(160),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlotPreview extends StatelessWidget {
  const _PlotPreview();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: CustomPaint(painter: _PlotFieldPainter()),
    );
  }
}

class _PlotPhotoPreview extends StatelessWidget {
  final File file;

  const _PlotPhotoPreview({required this.file});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.file(file, fit: BoxFit.cover),
    );
  }
}

class _FetPointGrid extends StatelessWidget {
  final List<_FetPointStatus> points;
  final Color Function(_FetPointStatus status) statusColor;
  final String Function(_FetPointStatus status) statusLabel;
  final ValueChanged<int> onTap;

  const _FetPointGrid({
    required this.points,
    required this.statusColor,
    required this.statusLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AspectRatio(
      aspectRatio: 10 / 5,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 10,
          crossAxisSpacing: 5,
          mainAxisSpacing: 5,
        ),
        itemCount: points.length,
        itemBuilder: (context, index) {
          final status = points[index];
          final color = statusColor(status);
          return InkWell(
            onTap: () => onTap(index),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withAlpha(isDark ? 62 : 22),
                shape: BoxShape.circle,
                border: Border.all(color: color),
              ),
              child: Text(
                statusLabel(status),
                maxLines: 1,
                style: AdvantaText.caption.copyWith(
                  color: isDark ? AdvantaColors.goldLight : color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(isDark ? 44 : 22),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: AdvantaText.caption.copyWith(
              color:
                  isDark ? AdvantaColors.goldLight : AdvantaColors.deepForest,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _GotPlantPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFF16210E);
    canvas.drawRect(Offset.zero & size, bg);

    final seedPaint = Paint()..color = const Color(0xFF4A3716);
    for (var y = 24.0; y < size.height; y += 22) {
      for (var x = 12.0; x < size.width; x += 28) {
        canvas.drawOval(
          Rect.fromCenter(center: Offset(x, y), width: 16, height: 10),
          seedPaint,
        );
      }
    }

    final stemPaint = Paint()
      ..color = AdvantaColors.success
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final leafPaint = Paint()
      ..color = AdvantaColors.lightGreen
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height * 0.58);
    canvas.drawLine(center, Offset(center.dx, size.height * 0.22), stemPaint);
    for (var i = 0; i < 6; i++) {
      final top = size.height * (0.28 + i * 0.065);
      final side = i.isEven ? -1.0 : 1.0;
      final path = Path()
        ..moveTo(center.dx, top)
        ..quadraticBezierTo(
          center.dx + side * size.width * 0.22,
          top - 28,
          center.dx + side * size.width * 0.32,
          top + 14,
        )
        ..quadraticBezierTo(
          center.dx + side * size.width * 0.18,
          top + 32,
          center.dx,
          top + 8,
        )
        ..close();
      canvas.drawPath(path, leafPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PlotFieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFF1D260F);
    canvas.drawRect(Offset.zero & size, bg);

    final rowPaint = Paint()
      ..color = const Color(0xFF5A3F17).withAlpha(150)
      ..strokeWidth = 8;
    for (var y = size.height * 0.12; y < size.height; y += size.height / 9) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 10), rowPaint);
    }

    final pointPaint = Paint()..color = AdvantaColors.lightGreen;
    for (var r = 0; r < 5; r++) {
      for (var c = 0; c < 10; c++) {
        final dx = size.width * (0.08 + c * 0.093);
        final dy = size.height * (0.18 + r * 0.16);
        canvas.drawCircle(Offset(dx, dy), 4.5, pointPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MiniPlantPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    _GotPlantPainter().paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MarkerFramePainter extends CustomPainter {
  final bool showCenter;
  final bool showGrid;

  const _MarkerFramePainter({
    this.showCenter = false,
    this.showGrid = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const len = 34.0;
    final rect = Rect.fromLTWH(12, 46, size.width - 24, size.height - 150);

    canvas.drawLine(
        rect.topLeft, rect.topLeft + const Offset(len, 0), linePaint);
    canvas.drawLine(
        rect.topLeft, rect.topLeft + const Offset(0, len), linePaint);
    canvas.drawLine(
        rect.topRight, rect.topRight - const Offset(len, 0), linePaint);
    canvas.drawLine(
        rect.topRight, rect.topRight + const Offset(0, len), linePaint);
    canvas.drawLine(
        rect.bottomLeft, rect.bottomLeft + const Offset(len, 0), linePaint);
    canvas.drawLine(
        rect.bottomLeft, rect.bottomLeft - const Offset(0, len), linePaint);
    canvas.drawLine(
        rect.bottomRight, rect.bottomRight - const Offset(len, 0), linePaint);
    canvas.drawLine(
        rect.bottomRight, rect.bottomRight - const Offset(0, len), linePaint);

    if (showCenter) {
      final center = rect.center;
      canvas.drawLine(center - const Offset(18, 0),
          center + const Offset(18, 0), linePaint);
      canvas.drawLine(center - const Offset(0, 18),
          center + const Offset(0, 18), linePaint);
    }

    if (showGrid) {
      final gridPaint = Paint()
        ..color = Colors.white.withAlpha(95)
        ..strokeWidth = 1;
      for (var i = 1; i < 10; i++) {
        final x = rect.left + rect.width * i / 10;
        canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), gridPaint);
      }
      for (var i = 1; i < 5; i++) {
        final y = rect.top + rect.height * i / 5;
        canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), gridPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
