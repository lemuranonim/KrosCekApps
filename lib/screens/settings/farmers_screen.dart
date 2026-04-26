// lib/screens/settings/farmers_screen.dart

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class FarmersScreen extends StatefulWidget {
  const FarmersScreen({super.key});

  @override
  State<FarmersScreen> createState() => _FarmersScreenState();
}

class _FarmersScreenState extends State<FarmersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();

  // Dummy data petani
  final List<Map<String, dynamic>> _farmers = [
    {'id': 'PT-001', 'name': 'Sugeng Widodo', 'phone': '0812-3456-7890', 'village': 'Desa Suko', 'district': 'Kec. Trawas', 'fields': 2, 'fa': 'Budi Santoso', 'status': 'Aktif'},
    {'id': 'PT-002', 'name': 'Siti Rahayu', 'phone': '0856-7890-1234', 'village': 'Desa Wringin', 'district': 'Kec. Pacet', 'fields': 1, 'fa': 'Agus Prasetyo', 'status': 'Aktif'},
    {'id': 'PT-003', 'name': 'Karto Sumarno', 'phone': '0821-1234-5678', 'village': 'Desa Randugede', 'district': 'Kec. Dlanggu', 'fields': 3, 'fa': 'Budi Santoso', 'status': 'Aktif'},
    {'id': 'PT-004', 'name': 'Hasan Basri', 'phone': '0878-9012-3456', 'village': 'Desa Jatirejo', 'district': 'Kec. Gondang', 'fields': 1, 'fa': 'Dian Permata', 'status': 'Tidak Aktif'},
    {'id': 'PT-005', 'name': 'Darmi Wulandari', 'phone': '0813-5678-9012', 'village': 'Desa Ngingasrembyong', 'district': 'Kec. Sooko', 'fields': 4, 'fa': 'Agus Prasetyo', 'status': 'Aktif'},
    {'id': 'PT-006', 'name': 'Joko Santoso', 'phone': '0857-0123-4567', 'village': 'Desa Puri', 'district': 'Kec. Puri', 'fields': 2, 'fa': 'Dian Permata', 'status': 'Aktif'},
  ];

  // Dummy data FA
  final List<Map<String, dynamic>> _fas = [
    {'id': 'FA-001', 'name': 'Budi Santoso', 'phone': '0812-1111-2222', 'area': 'Kec. Trawas, Kec. Dlanggu', 'farmers': 2, 'fields': 5, 'status': 'Aktif'},
    {'id': 'FA-002', 'name': 'Agus Prasetyo', 'phone': '0856-3333-4444', 'area': 'Kec. Pacet, Kec. Sooko', 'farmers': 2, 'fields': 5, 'status': 'Aktif'},
    {'id': 'FA-003', 'name': 'Dian Permata', 'phone': '0821-5555-6666', 'area': 'Kec. Gondang, Kec. Puri', 'farmers': 2, 'fields': 3, 'status': 'Aktif'},
    {'id': 'FA-004', 'name': 'Rini Susanti', 'phone': '0878-7777-8888', 'area': '-', 'farmers': 0, 'fields': 0, 'status': 'Tidak Aktif'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredFarmers {
    final q = _searchCtrl.text.toLowerCase();
    if (q.isEmpty) return _farmers;
    return _farmers.where((f) =>
    f['name'].toString().toLowerCase().contains(q) ||
        f['village'].toString().toLowerCase().contains(q) ||
        f['fa'].toString().toLowerCase().contains(q)).toList();
  }

  List<Map<String, dynamic>> get _filteredFAs {
    final q = _searchCtrl.text.toLowerCase();
    if (q.isEmpty) return _fas;
    return _fas.where((f) =>
    f['name'].toString().toLowerCase().contains(q) ||
        f['area'].toString().toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Petani & FA'),
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.people_outline, size: 18),
                  const SizedBox(width: 6),
                  Text('Petani (${_farmers.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.badge_outlined, size: 18),
                  const SizedBox(width: 6),
                  Text('FA (${_fas.length})'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: _tabController.index == 0
                    ? 'Cari petani, desa, atau FA...'
                    : 'Cari field assistant...',
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
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _FarmerList(
                  farmers: _filteredFarmers,
                  isDark: isDark,
                  theme: theme,
                ),
                _FAList(
                  fas: _filteredFAs,
                  isDark: isDark,
                  theme: theme,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FarmerList extends StatelessWidget {
  final List<Map<String, dynamic>> farmers;
  final bool isDark;
  final ThemeData theme;

  const _FarmerList({required this.farmers, required this.isDark, required this.theme});

  @override
  Widget build(BuildContext context) {
    if (farmers.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.people_outline, size: 64, color: AdvantaColors.mutedGrey.withAlpha(80)),
          const SizedBox(height: 16),
          Text('Tidak ada petani ditemukan',
              style: AdvantaText.body1.copyWith(color: AdvantaColors.mutedGrey)),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: farmers.length,
      itemBuilder: (ctx, i) {
        final f = farmers[i];
        final isActive = f['status'] == 'Aktif';
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: AdvantaRadius.cardRadius,
            border: Border.all(color: isDark ? Colors.white10 : Colors.black.withAlpha(12)),
          ),
          child: InkWell(
            borderRadius: AdvantaRadius.cardRadius,
            onTap: () => _showDetail(ctx, f),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: theme.colorScheme.primary.withAlpha(isDark ? 50 : 25),
                    child: Text(
                      f['name'].toString().split(' ').map((w) => w[0]).take(2).join(),
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(f['name'],
                          style: AdvantaText.bodyBold.copyWith(color: theme.colorScheme.onSurface),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text('${f['village']} · ${f['district']}',
                          style: AdvantaText.caption.copyWith(color: AdvantaColors.mutedGrey),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 5),
                      Row(children: [
                        _Chip(label: '${f['fields']} Lahan', color: theme.colorScheme.primary),
                        const SizedBox(width: 6),
                        _Chip(label: 'FA: ${f['fa']}', color: AdvantaColors.mutedGrey),
                        const SizedBox(width: 6),
                        _Chip(
                          label: f['status'],
                          color: isActive ? AdvantaColors.primaryGreen : AdvantaColors.mutedGrey,
                        ),
                      ]),
                    ]),
                  ),
                  Icon(Icons.chevron_right, color: AdvantaColors.mutedGrey.withAlpha(150)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDetail(BuildContext context, Map<String, dynamic> f) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: AdvantaRadius.sheetRadius),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.black12, borderRadius: BorderRadius.circular(2)))),
          Text(f['name'], style: AdvantaText.heading2.copyWith(color: theme.colorScheme.onSurface)),
          const SizedBox(height: 16),
          _InfoRow(icon: Icons.tag, label: 'ID', value: f['id']),
          _InfoRow(icon: Icons.phone_outlined, label: 'Telepon', value: f['phone']),
          _InfoRow(icon: Icons.location_on_outlined, label: 'Lokasi', value: '${f['village']}, ${f['district']}'),
          _InfoRow(icon: Icons.grass_outlined, label: 'Jumlah Lahan', value: '${f['fields']} lahan'),
          _InfoRow(icon: Icons.badge_outlined, label: 'Field Assistant', value: f['fa']),
          _InfoRow(icon: Icons.circle, label: 'Status', value: f['status']),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity,
              child: ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('TUTUP'))),
        ]),
      ),
    );
  }
}

class _FAList extends StatelessWidget {
  final List<Map<String, dynamic>> fas;
  final bool isDark;
  final ThemeData theme;

  const _FAList({required this.fas, required this.isDark, required this.theme});

  @override
  Widget build(BuildContext context) {
    if (fas.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.badge_outlined, size: 64, color: AdvantaColors.mutedGrey.withAlpha(80)),
          const SizedBox(height: 16),
          Text('Tidak ada FA ditemukan',
              style: AdvantaText.body1.copyWith(color: AdvantaColors.mutedGrey)),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: fas.length,
      itemBuilder: (ctx, i) {
        final f = fas[i];
        final isActive = f['status'] == 'Aktif';
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: AdvantaRadius.cardRadius,
            border: Border.all(color: isDark ? Colors.white10 : Colors.black.withAlpha(12)),
          ),
          child: InkWell(
            borderRadius: AdvantaRadius.cardRadius,
            onTap: () => _showDetail(ctx, f),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: AdvantaColors.gold.withAlpha(isDark ? 50 : 25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.badge_outlined, color: AdvantaColors.gold, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(f['name'],
                        style: AdvantaText.bodyBold.copyWith(color: theme.colorScheme.onSurface),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(f['area'], style: AdvantaText.caption.copyWith(color: AdvantaColors.mutedGrey),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 5),
                    Row(children: [
                      _Chip(label: '${f['farmers']} Petani', color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      _Chip(label: '${f['fields']} Lahan', color: AdvantaColors.midGreen),
                      const SizedBox(width: 6),
                      _Chip(
                        label: f['status'],
                        color: isActive ? AdvantaColors.primaryGreen : AdvantaColors.mutedGrey,
                      ),
                    ]),
                  ]),
                ),
                Icon(Icons.chevron_right, color: AdvantaColors.mutedGrey.withAlpha(150)),
              ]),
            ),
          ),
        );
      },
    );
  }

  void _showDetail(BuildContext context, Map<String, dynamic> f) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: AdvantaRadius.sheetRadius),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.black12, borderRadius: BorderRadius.circular(2)))),
          Text(f['name'], style: AdvantaText.heading2.copyWith(color: theme.colorScheme.onSurface)),
          const SizedBox(height: 16),
          _InfoRow(icon: Icons.tag, label: 'ID', value: f['id']),
          _InfoRow(icon: Icons.phone_outlined, label: 'Telepon', value: f['phone']),
          _InfoRow(icon: Icons.map_outlined, label: 'Wilayah', value: f['area']),
          _InfoRow(icon: Icons.people_outline, label: 'Jumlah Petani', value: '${f['farmers']} petani'),
          _InfoRow(icon: Icons.grass_outlined, label: 'Total Lahan', value: '${f['fields']} lahan'),
          _InfoRow(icon: Icons.circle, label: 'Status', value: f['status']),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity,
              child: ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('TUTUP'))),
        ]),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: AdvantaColors.mutedGrey),
        const SizedBox(width: 10),
        Text('$label:', style: AdvantaText.caption.copyWith(color: AdvantaColors.mutedGrey)),
        const SizedBox(width: 8),
        Expanded(child: Text(value,
            style: AdvantaText.bodyBold.copyWith(color: theme.colorScheme.onSurface, fontSize: 13),
            textAlign: TextAlign.end)),
      ]),
    );
  }
}