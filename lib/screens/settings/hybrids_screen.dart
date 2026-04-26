// lib/screens/settings/hybrids_screen.dart

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class HybridsScreen extends StatefulWidget {
  const HybridsScreen({super.key});

  @override
  State<HybridsScreen> createState() => _HybridsScreenState();
}

class _HybridsScreenState extends State<HybridsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedCrop = 'Semua';

  final List<String> _crops = ['Semua', 'Padi', 'Jagung', 'Cabai', 'Kedelai'];

  // Dummy data hybrid/varietas
  final List<Map<String, dynamic>> _hybrids = [
    {
      'code': 'VAR-001',
      'name': 'Inpari 32',
      'crop': 'Padi',
      'type': 'Inbrida',
      'umur': '115-120 HST',
      'potensi': '9.0 t/ha',
      'ketahanan': 'Tahan Blast, BLB',
      'status': 'Aktif',
      'desc': 'Varietas padi sawah dengan potensi hasil tinggi dan tahan terhadap penyakit blast dan hawar daun bakteri.',
    },
    {
      'code': 'VAR-002',
      'name': 'Ciherang',
      'crop': 'Padi',
      'type': 'Inbrida',
      'umur': '116-125 HST',
      'potensi': '6.0 t/ha',
      'ketahanan': 'Agak tahan BLB',
      'status': 'Aktif',
      'desc': 'Varietas padi sawah populer yang banyak ditanam oleh petani karena adaptasinya yang luas.',
    },
    {
      'code': 'VAR-003',
      'name': 'NK 7328',
      'crop': 'Jagung',
      'type': 'Hibrida',
      'umur': '90-95 HST',
      'potensi': '12.5 t/ha',
      'ketahanan': 'Tahan Busuk Tongkol',
      'status': 'Aktif',
      'desc': 'Hibrida jagung dengan batang kokoh, adaptasi luas, dan cocok untuk lahan kering maupun irigasi.',
    },
    {
      'code': 'VAR-004',
      'name': 'DK 979',
      'crop': 'Jagung',
      'type': 'Hibrida',
      'umur': '95-100 HST',
      'potensi': '13.0 t/ha',
      'ketahanan': 'Tahan Lodging',
      'status': 'Aktif',
      'desc': 'Hibrida jagung dengan tongkol ganda dan potensi hasil sangat tinggi.',
    },
    {
      'code': 'VAR-005',
      'name': 'Hot Beauty',
      'crop': 'Cabai',
      'type': 'Hibrida',
      'umur': '75-80 HST',
      'potensi': '18 t/ha',
      'ketahanan': 'Tahan Antraknosa',
      'status': 'Aktif',
      'desc': 'Varietas cabai merah besar hibrida dengan buah seragam dan produksi tinggi.',
    },
    {
      'code': 'VAR-006',
      'name': 'Anjasmoro',
      'crop': 'Kedelai',
      'type': 'Inbrida',
      'umur': '82-92 HST',
      'potensi': '2.3 t/ha',
      'ketahanan': 'Agak tahan Karat Daun',
      'status': 'Tidak Aktif',
      'desc': 'Varietas kedelai dengan biji besar dan protein tinggi, cocok untuk lahan sawah irigasi.',
    },
    {
      'code': 'VAR-007',
      'name': 'Pandan Wangi',
      'crop': 'Padi',
      'type': 'Inbrida',
      'umur': '140-145 HST',
      'potensi': '5.0 t/ha',
      'ketahanan': 'Aromatik',
      'status': 'Aktif',
      'desc': 'Padi aromatik premium dengan aroma khas dan rasa nasi yang pulen.',
    },
  ];

  List<Map<String, dynamic>> get _filtered {
    final q = _searchCtrl.text.toLowerCase();
    return _hybrids.where((h) {
      final matchCrop = _selectedCrop == 'Semua' || h['crop'] == _selectedCrop;
      final matchSearch = q.isEmpty ||
          h['name'].toString().toLowerCase().contains(q) ||
          h['code'].toString().toLowerCase().contains(q) ||
          h['type'].toString().toLowerCase().contains(q);
      return matchCrop && matchSearch;
    }).toList();
  }

  Color _cropColor(String crop) {
    switch (crop) {
      case 'Padi': return AdvantaColors.primaryGreen;
      case 'Jagung': return Colors.amber.shade700;
      case 'Cabai': return Colors.red.shade600;
      case 'Kedelai': return Colors.brown.shade400;
      default: return AdvantaColors.mutedGrey;
    }
  }

  IconData _cropIcon(String crop) {
    switch (crop) {
      case 'Padi': return Icons.grass_outlined;
      case 'Jagung': return Icons.eco_outlined;
      case 'Cabai': return Icons.local_fire_department_outlined;
      case 'Kedelai': return Icons.circle_outlined;
      default: return Icons.science_outlined;
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final filtered = _filtered;

    // Group by crop for summary
    final Map<String, int> cropCount = {};
    for (final h in _hybrids) {
      cropCount[h['crop']] = (cropCount[h['crop']] ?? 0) + 1;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hybrid & Varietas'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Summary banner
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [AdvantaColors.deepForest, const Color(0xFF112E20)]
                    : [AdvantaColors.primaryGreen, AdvantaColors.midGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.science_outlined, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${_hybrids.length} varietas terdaftar · ${_hybrids.where((h) => h['status'] == 'Aktif').length} aktif',
                    style: AdvantaText.bodyBold.copyWith(color: Colors.white, fontSize: 13),
                  ),
                ),
                ..._crops.skip(1).map((crop) => Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${cropCount[crop] ?? 0} $crop',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
                )),
              ],
            ),
          ),

          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Cari varietas, kode, tipe...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () { _searchCtrl.clear(); setState(() {}); },
                )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // Crop filter chips
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _crops.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final c = _crops[i];
                final selected = _selectedCrop == c;
                return ChoiceChip(
                  label: Text(c),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedCrop = c),
                  selectedColor: theme.colorScheme.primary,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : theme.colorScheme.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Row(children: [
              Icon(Icons.science_outlined, size: 14, color: AdvantaColors.mutedGrey),
              const SizedBox(width: 4),
              Text('${filtered.length} varietas',
                  style: AdvantaText.caption.copyWith(color: AdvantaColors.mutedGrey)),
            ]),
          ),

          // List
          Expanded(
            child: filtered.isEmpty
                ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.science_outlined, size: 64, color: AdvantaColors.mutedGrey.withAlpha(80)),
                const SizedBox(height: 16),
                Text('Tidak ada varietas ditemukan',
                    style: AdvantaText.body1.copyWith(color: AdvantaColors.mutedGrey)),
              ]),
            )
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final h = filtered[i];
                final color = _cropColor(h['crop']);
                final isActive = h['status'] == 'Aktif';
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color,
                    borderRadius: AdvantaRadius.cardRadius,
                    border: Border.all(color: isDark ? Colors.white10 : Colors.black.withAlpha(12)),
                  ),
                  child: InkWell(
                    borderRadius: AdvantaRadius.cardRadius,
                    onTap: () => _showDetail(context, h, color, isDark, theme),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: color.withAlpha(isDark ? 50 : 25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(_cropIcon(h['crop']), color: color, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(child: Text(h['name'],
                                  style: AdvantaText.bodyBold.copyWith(color: theme.colorScheme.onSurface),
                                  maxLines: 1, overflow: TextOverflow.ellipsis)),
                              if (!isActive)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AdvantaColors.mutedGrey.withAlpha(30),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text('Tidak Aktif',
                                      style: TextStyle(color: AdvantaColors.mutedGrey, fontSize: 9, fontWeight: FontWeight.w700)),
                                ),
                            ]),
                            const SizedBox(height: 3),
                            Text('${h['code']} · ${h['type']} · ${h['crop']}',
                                style: AdvantaText.caption.copyWith(color: AdvantaColors.mutedGrey)),
                            const SizedBox(height: 5),
                            Row(children: [
                              _MiniTag(label: '⏱ ${h['umur']}', color: color),
                              const SizedBox(width: 6),
                              _MiniTag(label: '📈 ${h['potensi']}', color: color),
                            ]),
                          ]),
                        ),
                        Icon(Icons.chevron_right, color: AdvantaColors.mutedGrey.withAlpha(150)),
                      ]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showDetail(BuildContext context, Map<String, dynamic> h, Color color, bool isDark, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: AdvantaRadius.sheetRadius),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scroll) => SingleChildScrollView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.black12, borderRadius: BorderRadius.circular(2)))),
            Row(children: [
              Container(width: 40, height: 40,
                  decoration: BoxDecoration(color: color.withAlpha(isDark ? 50 : 25), borderRadius: BorderRadius.circular(10)),
                  child: Icon(_cropIcon(h['crop']), color: color, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(h['name'], style: AdvantaText.heading2.copyWith(color: theme.colorScheme.onSurface)),
                Text('${h['code']} · ${h['type']}', style: AdvantaText.caption.copyWith(color: AdvantaColors.mutedGrey)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(8)),
                child: Text(h['crop'], style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(isDark ? 20 : 10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.colorScheme.primary.withAlpha(30)),
              ),
              child: Text(h['desc'], style: AdvantaText.body2.copyWith(color: theme.colorScheme.onSurface)),
            ),
            const SizedBox(height: 16),
            Text('SPESIFIKASI', style: AdvantaText.caption.copyWith(
                color: AdvantaColors.mutedGrey, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _SpecRow(label: 'Umur Panen', value: h['umur'], icon: Icons.schedule_outlined, color: color),
            _SpecRow(label: 'Potensi Hasil', value: h['potensi'], icon: Icons.bar_chart_outlined, color: color),
            _SpecRow(label: 'Ketahanan', value: h['ketahanan'], icon: Icons.shield_outlined, color: color),
            _SpecRow(label: 'Status', value: h['status'], icon: Icons.circle_outlined,
                color: h['status'] == 'Aktif' ? AdvantaColors.primaryGreen : AdvantaColors.mutedGrey),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity,
                child: ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('TUTUP'))),
          ]),
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

class _SpecRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SpecRow({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        Container(width: 32, height: 32,
            decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: color)),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: AdvantaText.body2.copyWith(color: AdvantaColors.mutedGrey))),
        Text(value, style: AdvantaText.bodyBold.copyWith(color: theme.colorScheme.onSurface, fontSize: 13)),
      ]),
    );
  }
}