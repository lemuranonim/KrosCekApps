import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';

enum _FetPointStatus { grown, notGrown, review, notReadable }

class GotFetScreen extends StatefulWidget {
  const GotFetScreen({super.key});

  @override
  State<GotFetScreen> createState() => _GotFetScreenState();
}

class _GotFetScreenState extends State<GotFetScreen> {
  final _dateFormat = DateFormat('dd MMM yyyy');

  late final List<_GotFetSample> _samples;
  late List<_FetPointStatus> _replicationOne;
  late List<_FetPointStatus> _replicationTwo;

  int _selectedIndex = 0;
  int _selectedSampleIndex = 0;
  int _selectedReplication = 1;

  int _gotTotalObserved = 100;
  int _gotOffType = 3;
  int _gotSelfing = 2;
  int _gotMale = 1;
  int _gotSuspicious = 2;

  @override
  void initState() {
    super.initState();
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

  _GotFetSample get _selectedSample => _samples[_selectedSampleIndex];

  int get _gotTrueType =>
      math.max(0, _gotTotalObserved - _gotOffType - _gotSelfing - _gotMale);

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

  double get _fetEmergence => (_fetTotalGrown / 100) * 100;

  List<_FetPointStatus> get _currentReplication =>
      _selectedReplication == 1 ? _replicationOne : _replicationTwo;

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildTrackingPage(),
      _buildGotPage(),
      _buildFetPage(),
      _buildReviewPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('GOT & FET'),
        actions: [
          IconButton(
            tooltip: 'User Settings',
            icon: const Icon(Icons.account_circle_rounded),
            onPressed: () => context.push('/got-fet/settings'),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (value) =>
            setState(() => _selectedIndex = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping_rounded),
            label: 'Tracking',
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

  Widget _buildTrackingPage() {
    return _PageScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroHeader(
            icon: Icons.route_rounded,
            title: 'Seed Quality Tracking',
            subtitle:
                'Sample movement, observation status, and decision aging.',
          ),
          const SizedBox(height: 16),
          _buildDashboardMetrics(),
          const SizedBox(height: 16),
          _buildSamplePicker(),
          const SizedBox(height: 16),
          _buildTimelineCard(_selectedSample),
          const SizedBox(height: 16),
          Text('Sample Queue', style: _sectionTitle(context)),
          const SizedBox(height: 10),
          for (var i = 0; i < _samples.length; i++) ...[
            _buildSampleCard(_samples[i], i),
            if (i != _samples.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildGotPage() {
    return _PageScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroHeader(
            icon: Icons.eco_rounded,
            title: 'GOT Result',
            subtitle:
                'Genetic purity, off-type count, photo evidence, and approval.',
          ),
          const SizedBox(height: 16),
          _buildSamplePicker(),
          const SizedBox(height: 16),
          _buildGotSummaryCard(),
          const SizedBox(height: 16),
          _buildGotInputCard(),
          const SizedBox(height: 16),
          _buildPhotoStandardCard(),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save Draft'),
                  onPressed: () => _showSnack('Draft GOT tersimpan lokal.'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Submit'),
                  onPressed: () {
                    _selectedSample.status = 'Submitted';
                    setState(() {});
                    _showSnack(
                        'GOT result ${_selectedSample.lotId} submitted.');
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFetPage() {
    return _PageScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroHeader(
            icon: Icons.grid_on_rounded,
            title: 'FET Plot Scanner',
            subtitle:
                '50 planting holes per replication, 2 replications, 100 points.',
          ),
          const SizedBox(height: 16),
          _buildSamplePicker(),
          const SizedBox(height: 16),
          _buildFetSummaryCard(),
          const SizedBox(height: 16),
          _buildReplicationSelector(),
          const SizedBox(height: 12),
          _buildFetGridCard(),
          const SizedBox(height: 16),
          _buildFetLegend(),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Capture'),
                  onPressed: () => _showSnack(
                      'Camera overlay disiapkan untuk tahap berikutnya.'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('Save Rep'),
                  onPressed: _saveFetReplication,
                ),
              ),
            ],
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
          _buildHeroHeader(
            icon: Icons.fact_check_rounded,
            title: 'Review Queue',
            subtitle:
                'Supervisor validation, revision request, approval, and final decision.',
          ),
          const SizedBox(height: 16),
          _buildReviewMetrics(),
          const SizedBox(height: 16),
          _buildSamplePicker(),
          const SizedBox(height: 16),
          _buildReviewDetailCard(),
          const SizedBox(height: 16),
          for (final sample in _samples) ...[
            _buildReviewQueueCard(sample),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildHeroHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor =
        isDark ? AdvantaColors.goldLight : AdvantaColors.deepForest;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AdvantaColors.midGreen : Colors.white,
        borderRadius: AdvantaRadius.cardRadius,
        border: Border.all(
          color: isDark
              ? AdvantaColors.goldLight.withAlpha(40)
              : AdvantaColors.dividerGrey,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AdvantaColors.gold.withAlpha(isDark ? 44 : 24),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AdvantaColors.gold),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AdvantaText.heading2.copyWith(color: textColor)),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AdvantaText.body2.copyWith(
                    color: isDark
                        ? AdvantaColors.goldLight.withAlpha(165)
                        : AdvantaColors.mutedGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardMetrics() {
    final total = _samples.length;
    final needReview =
        _samples.where((sample) => sample.status == 'Need Review').length;
    final overdue = _samples.where((sample) => sample.isOverdue).length;
    final approved =
        _samples.where((sample) => sample.status == 'Approved').length;

    return _MetricGrid(
      cards: [
        _MetricData('Total', total.toString(), Icons.inventory_2_rounded,
            AdvantaColors.primaryGreen),
        _MetricData('Need Review', needReview.toString(),
            Icons.rate_review_rounded, AdvantaColors.gold),
        _MetricData('Overdue', overdue.toString(), Icons.warning_rounded,
            AdvantaColors.error),
        _MetricData('Approved', approved.toString(), Icons.verified_rounded,
            AdvantaColors.success),
      ],
    );
  }

  Widget _buildReviewMetrics() {
    return _MetricGrid(
      cards: [
        _MetricData('Purity', '${_gotPurity.toStringAsFixed(1)}%',
            Icons.eco_rounded, AdvantaColors.primaryGreen),
        _MetricData('Emergence', '${_fetEmergence.toStringAsFixed(1)}%',
            Icons.grass_rounded, AdvantaColors.success),
        _MetricData('Review Point', _fetTotalReview.toString(),
            Icons.help_rounded, AdvantaColors.gold),
        _MetricData('Decision', _selectedSample.status, Icons.flag_rounded,
            _statusColor(_selectedSample.status)),
      ],
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

  Widget _buildSampleCard(_GotFetSample sample, int index) {
    final isSelected = index == _selectedSampleIndex;
    final color = _statusColor(sample.status);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      color: isSelected
          ? color.withAlpha(isDark ? 45 : 22)
          : theme.cardTheme.color,
      child: InkWell(
        onTap: () => setState(() => _selectedSampleIndex = index),
        borderRadius: AdvantaRadius.cardRadius,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      sample.lotId,
                      style: AdvantaText.heading3.copyWith(
                        color: isDark
                            ? AdvantaColors.goldLight
                            : AdvantaColors.deepForest,
                      ),
                    ),
                  ),
                  _StatusPill(label: sample.status, color: color),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${sample.hybrid} | ${sample.crop} | ${sample.season}',
                style: AdvantaText.body2.copyWith(
                  color: isDark
                      ? AdvantaColors.goldLight.withAlpha(160)
                      : AdvantaColors.mutedGrey,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _MiniFact(label: 'PIC', value: sample.pic)),
                  Expanded(
                      child: _MiniFact(
                          label: 'Due',
                          value: _dateFormat.format(sample.dueDate))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineCard(_GotFetSample sample) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    sample.sampleId,
                    style: AdvantaText.heading3.copyWith(
                      color: isDark
                          ? AdvantaColors.goldLight
                          : AdvantaColors.deepForest,
                    ),
                  ),
                ),
                _StatusPill(
                    label: sample.testType, color: AdvantaColors.primaryGreen),
              ],
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < sample.steps.length; i++)
              _TimelineRow(
                step: sample.steps[i],
                isLast: i == sample.steps.length - 1,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGotSummaryCard() {
    return _MetricGrid(
      cards: [
        _MetricData('True Type', _gotTrueType.toString(),
            Icons.check_circle_rounded, AdvantaColors.success),
        _MetricData('Purity', '${_gotPurity.toStringAsFixed(2)}%',
            Icons.percent_rounded, AdvantaColors.primaryGreen),
        _MetricData('Issue', (_gotOffType + _gotSelfing + _gotMale).toString(),
            Icons.report_rounded, AdvantaColors.error),
        _MetricData('Suspicious', _gotSuspicious.toString(), Icons.help_rounded,
            AdvantaColors.gold),
      ],
    );
  }

  Widget _buildGotInputCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor =
        isDark ? AdvantaColors.goldLight : AdvantaColors.deepForest;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Observation Counts',
                style: AdvantaText.heading3.copyWith(color: textColor)),
            const SizedBox(height: 12),
            _CounterRow(
              label: 'Total Observed',
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
              label: 'Suspicious',
              value: _gotSuspicious,
              onAdd: () => _adjustGotCount('suspicious', 1),
              onRemove: () => _adjustGotCount('suspicious', -1),
            ),
            const Divider(height: 28),
            Text(
              'True Type = Total Observed - Off-type - Selfing - Male',
              style: AdvantaText.caption.copyWith(
                color: isDark
                    ? AdvantaColors.goldLight.withAlpha(160)
                    : AdvantaColors.mutedGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoStandardCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor =
        isDark ? AdvantaColors.goldLight : AdvantaColors.deepForest;

    final standards = [
      ('Angle', 'OK', Icons.screen_rotation_alt_rounded, AdvantaColors.success),
      ('Focus', 'OK', Icons.center_focus_strong_rounded, AdvantaColors.success),
      ('Distance', 'Warning', Icons.straighten_rounded, AdvantaColors.gold),
      ('Light', 'OK', Icons.wb_sunny_rounded, AdvantaColors.success),
    ];

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Photo Evidence',
                style: AdvantaText.heading3.copyWith(color: textColor)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final item in standards)
                  _ValidationChip(
                    label: item.$1,
                    value: item.$2,
                    icon: item.$3,
                    color: item.$4,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.photo_camera_rounded),
                    label: const Text('Capture'),
                    onPressed: () => _showSnack(
                        'Guided capture masuk tahap camera overlay.'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.upload_file_rounded),
                    label: const Text('Upload'),
                    onPressed: () => _showSnack(
                        'Upload photo evidence masuk tahap storage.'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFetSummaryCard() {
    return _MetricGrid(
      cards: [
        _MetricData('Grown', _fetTotalGrown.toString(), Icons.grass_rounded,
            AdvantaColors.success),
        _MetricData('Not Grown', _fetTotalNotGrown.toString(),
            Icons.close_rounded, AdvantaColors.error),
        _MetricData('Review', _fetTotalReview.toString(), Icons.help_rounded,
            AdvantaColors.gold),
        _MetricData('Unreadable', _fetTotalNotReadable.toString(),
            Icons.visibility_off_rounded, AdvantaColors.mutedGrey),
        _MetricData('Emergence', '${_fetEmergence.toStringAsFixed(1)}%',
            Icons.percent_rounded, AdvantaColors.primaryGreen),
      ],
    );
  }

  Widget _buildReplicationSelector() {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<int>(
        segments: const [
          ButtonSegment<int>(
            value: 1,
            label: Text('Rep 1'),
            icon: Icon(Icons.looks_one_rounded),
          ),
          ButtonSegment<int>(
            value: 2,
            label: Text('Rep 2'),
            icon: Icon(Icons.looks_two_rounded),
          ),
        ],
        selected: {_selectedReplication},
        onSelectionChanged: (selection) {
          setState(() => _selectedReplication = selection.first);
        },
      ),
    );
  }

  Widget _buildFetGridCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor =
        isDark ? AdvantaColors.goldLight : AdvantaColors.deepForest;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Visual Grid 5 x 10',
                    style: AdvantaText.heading3.copyWith(color: textColor),
                  ),
                ),
                Text(
                  '50 points',
                  style: AdvantaText.caption.copyWith(
                    color: isDark
                        ? AdvantaColors.goldLight.withAlpha(160)
                        : AdvantaColors.mutedGrey,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 10 / 5,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 10,
                  crossAxisSpacing: 5,
                  mainAxisSpacing: 5,
                ),
                itemCount: _currentReplication.length,
                itemBuilder: (context, index) {
                  final status = _currentReplication[index];
                  final color = _fetStatusColor(status);
                  return Tooltip(
                    message: 'Hole ${index + 1}: ${_fetStatusLabel(status)}',
                    child: InkWell(
                      onTap: () => _cycleFetPoint(index),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: color.withAlpha(isDark ? 70 : 42),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: color, width: 1.2),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: AdvantaText.caption.copyWith(
                            color: isDark
                                ? Colors.white
                                : AdvantaColors.deepForest,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
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

  Widget _buildReviewDetailCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor =
        isDark ? AdvantaColors.goldLight : AdvantaColors.deepForest;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_selectedSample.lotId,
                style: AdvantaText.heading2.copyWith(color: textColor)),
            const SizedBox(height: 6),
            Text(
              '${_selectedSample.hybrid} | ${_selectedSample.testType} | ${_selectedSample.pic}',
              style: AdvantaText.body2.copyWith(
                color: isDark
                    ? AdvantaColors.goldLight.withAlpha(160)
                    : AdvantaColors.mutedGrey,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ReviewValue(
                    label: 'GOT Purity',
                    value: '${_gotPurity.toStringAsFixed(2)}%',
                    color: AdvantaColors.primaryGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ReviewValue(
                    label: 'FET Emergence',
                    value: '${_fetEmergence.toStringAsFixed(2)}%',
                    color: AdvantaColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.assignment_return_rounded),
                  label: const Text('Revision'),
                  onPressed: () => _setReviewDecision('Revision Required'),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.pause_circle_outline_rounded),
                  label: const Text('Hold'),
                  onPressed: () => _setReviewDecision('Hold'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.verified_rounded),
                  label: const Text('Approve'),
                  onPressed: () => _setReviewDecision('Approved'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewQueueCard(_GotFetSample sample) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AdvantaColors.midGreen : Colors.white,
        borderRadius: AdvantaRadius.cardRadius,
        border: Border.all(
          color: isDark
              ? AdvantaColors.goldLight.withAlpha(36)
              : AdvantaColors.dividerGrey,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _statusColor(sample.status).withAlpha(isDark ? 55 : 25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.science_rounded,
                color: _statusColor(sample.status), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sample.lotId,
                  style: AdvantaText.bodyBold.copyWith(
                    color: isDark
                        ? AdvantaColors.goldLight
                        : AdvantaColors.deepForest,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sample.status,
                  style: AdvantaText.caption.copyWith(
                    color: isDark
                        ? AdvantaColors.goldLight.withAlpha(160)
                        : AdvantaColors.mutedGrey,
                  ),
                ),
              ],
            ),
          ),
          _StatusPill(
              label: sample.testType, color: AdvantaColors.primaryGreen),
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
    final points = _currentReplication;
    final current = points[index];
    final next = switch (current) {
      _FetPointStatus.grown => _FetPointStatus.notGrown,
      _FetPointStatus.notGrown => _FetPointStatus.review,
      _FetPointStatus.review => _FetPointStatus.notReadable,
      _FetPointStatus.notReadable => _FetPointStatus.grown,
    };

    setState(() {
      points[index] = next;
    });
  }

  void _saveFetReplication() {
    final reviewCount =
        _countStatus(_currentReplication, _FetPointStatus.review);
    final notReadableCount =
        _countStatus(_currentReplication, _FetPointStatus.notReadable);

    if (reviewCount > 0 || notReadableCount > 0) {
      _showSnack(
          'Konfirmasi semua Review / Not Readable sebelum final submit.');
      return;
    }

    _selectedSample.status = 'Submitted';
    setState(() {});
    _showSnack('FET Rep $_selectedReplication tersimpan.');
  }

  void _setReviewDecision(String status) {
    setState(() => _selectedSample.status = status);
    _showSnack('Decision ${_selectedSample.lotId}: $status');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  int _countStatus(List<_FetPointStatus> points, _FetPointStatus status) {
    return points.where((point) => point == status).length;
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
      _FetPointStatus.grown => 'Grown',
      _FetPointStatus.notGrown => 'Not Grown',
      _FetPointStatus.review => 'Review',
      _FetPointStatus.notReadable => 'Not Readable',
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AdvantaText.heading3.copyWith(
      color: isDark ? AdvantaColors.goldLight : AdvantaColors.deepForest,
    );
  }

  List<_GotFetSample> _seedSamples() {
    return [
      _GotFetSample(
        lotId: 'DS26-FC-00125',
        sampleId: 'GOTFET-001',
        hybrid: 'ADV-XXX',
        crop: 'Field Corn',
        season: 'DS 2026',
        testType: 'GOT + FET',
        status: 'Need Review',
        pic: 'Observer A',
        dueDate: DateTime(2026, 5, 24),
        steps: [
          _TrackingStep('Sample Created', DateTime(2026, 5, 12), true),
          _TrackingStep('Dispatched', DateTime(2026, 5, 13), true),
          _TrackingStep('Received', DateTime(2026, 5, 14), true),
          _TrackingStep('Planted', DateTime(2026, 5, 15), true),
          _TrackingStep('Observed', DateTime(2026, 5, 21), true),
          _TrackingStep('Reviewed', DateTime(2026, 5, 22), false),
          _TrackingStep('Final Decision', DateTime(2026, 5, 24), false),
        ],
      ),
      _GotFetSample(
        lotId: 'DS26-SC-00045',
        sampleId: 'FET-045',
        hybrid: 'ADV-SC1',
        crop: 'Sweet Corn',
        season: 'DS 2026',
        testType: 'FET',
        status: 'Observation Due',
        pic: 'Observer B',
        dueDate: DateTime(2026, 5, 20),
        steps: [
          _TrackingStep('Sample Created', DateTime(2026, 5, 9), true),
          _TrackingStep('Dispatched', DateTime(2026, 5, 10), true),
          _TrackingStep('Received', DateTime(2026, 5, 11), true),
          _TrackingStep('Planted', DateTime(2026, 5, 12), true),
          _TrackingStep('Observed', DateTime(2026, 5, 20), false),
          _TrackingStep('Reviewed', DateTime(2026, 5, 21), false),
          _TrackingStep('Final Decision', DateTime(2026, 5, 22), false),
        ],
      ),
      _GotFetSample(
        lotId: 'DS26-FC-00140',
        sampleId: 'GOT-140',
        hybrid: 'ADV-FC2',
        crop: 'Field Corn',
        season: 'DS 2026',
        testType: 'GOT',
        status: 'In Transit',
        pic: 'GOT Site A',
        dueDate: DateTime(2026, 5, 28),
        steps: [
          _TrackingStep('Sample Created', DateTime(2026, 5, 18), true),
          _TrackingStep('Dispatched', DateTime(2026, 5, 20), true),
          _TrackingStep('Received', DateTime(2026, 5, 21), false),
          _TrackingStep('Planted', DateTime(2026, 5, 23), false),
          _TrackingStep('Observed', DateTime(2026, 5, 28), false),
          _TrackingStep('Reviewed', DateTime(2026, 5, 29), false),
          _TrackingStep('Final Decision', DateTime(2026, 5, 30), false),
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: child,
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
        status != 'Final Decision';
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
          childAspectRatio: crossAxisCount == 4 ? 2.3 : 1.45,
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AdvantaColors.midGreen : Colors.white,
        borderRadius: AdvantaRadius.cardRadius,
        border: Border.all(
          color: isDark
              ? AdvantaColors.goldLight.withAlpha(36)
              : AdvantaColors.dividerGrey,
        ),
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
                    color: isDark
                        ? AdvantaColors.goldLight
                        : AdvantaColors.deepForest,
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
                      ? AdvantaColors.goldLight.withAlpha(150)
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

class _TimelineRow extends StatelessWidget {
  final _TrackingStep step;
  final bool isLast;

  const _TimelineRow({
    required this.step,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = step.done ? AdvantaColors.success : AdvantaColors.mutedGrey;
    final dateFormat = DateFormat('dd MMM yyyy');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: color.withAlpha(step.done ? 255 : 80),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  step.done ? Icons.check_rounded : Icons.more_horiz_rounded,
                  color: Colors.white,
                  size: 15,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: color.withAlpha(75),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: AdvantaText.bodyBold.copyWith(
                      color: isDark
                          ? AdvantaColors.goldLight
                          : AdvantaColors.deepForest,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateFormat.format(step.date),
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(isDark ? 48 : 24),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AdvantaText.caption.copyWith(
          color: isDark ? AdvantaColors.goldLight : color,
          fontWeight: FontWeight.w800,
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AdvantaText.bodyBold.copyWith(
                color:
                    isDark ? AdvantaColors.goldLight : AdvantaColors.deepForest,
              ),
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Kurangi $label',
            onPressed: onRemove,
            icon: const Icon(Icons.remove_rounded),
          ),
          SizedBox(
            width: 54,
            child: Text(
              value.toString(),
              textAlign: TextAlign.center,
              style: AdvantaText.heading3.copyWith(
                color:
                    isDark ? AdvantaColors.goldLight : AdvantaColors.deepForest,
              ),
            ),
          ),
          IconButton.filled(
            tooltip: 'Tambah $label',
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _ValidationChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _ValidationChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withAlpha(isDark ? 44 : 22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(115)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 7),
          Text(
            '$label $value',
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

class _ReviewValue extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ReviewValue({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(isDark ? 44 : 22),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: AdvantaText.heading2.copyWith(
              color:
                  isDark ? AdvantaColors.goldLight : AdvantaColors.deepForest,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AdvantaText.caption.copyWith(
              color: isDark
                  ? AdvantaColors.goldLight.withAlpha(150)
                  : AdvantaColors.mutedGrey,
            ),
          ),
        ],
      ),
    );
  }
}
