// lib/screens/settings/fields_screen.dart

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/advanta_loading_state.dart';

class FieldsScreen extends StatefulWidget {
  const FieldsScreen({super.key});

  @override
  State<FieldsScreen> createState() => _FieldsScreenState();
}

class _FieldsScreenState extends State<FieldsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedFilter = 'Semua';
  final bool _isLoading = false;

  final List<String> _filters = ['Semua', 'Aktif', 'Tidak Aktif', 'Belum Verifikasi'];

  // Dummy data — ganti dengan data dari provider/API
  final List<Map<String, dynamic>> _fields = [
    {
      'id': 'LH-001',
      'name': 'Lahan Blok A - Desa Suko',
      'area': '2.5 Ha',
      'location': 'Desa Suko, Kec. Trawas, Kab. Mojokerto',
      'status': 'Aktif',
      'crop': 'Padi Hibrida',
      'farmer': 'Pak Sugeng',
    },
    {
      'id': 'LH-002',
      'name': 'Lahan Blok B - Desa Wringin',
      'area': '1.8 Ha',
      'location': 'Desa Wringin, Kec. Pacet, Kab. Mojokerto',
      'status': 'Aktif',
      'crop': 'Jagung Hibrida',
      'farmer': 'Bu Siti',
    },
    {
      'id': 'LH-003',
      'name': 'Lahan Blok C - Desa Randugede',
      'area': '3.2 Ha',
      'location': 'Desa Randugede, Kec. Dlanggu, Kab. Mojokerto',
      'status': 'Belum Verifikasi',
      'crop': 'Padi Hibrida',
      'farmer': 'Pak Karto',
    },
    {
      'id': 'LH-004',
      'name': 'Lahan Blok D - Desa Jatirejo',
      'area': '0.9 Ha',
      'location': 'Desa Jatirejo, Kec. Gondang, Kab. Mojokerto',
      'status': 'Tidak Aktif',
      'crop': '-',
      'farmer': 'Pak Hasan',
    },
    {
      'id': 'LH-005',
      'name': 'Lahan Blok E - Desa Ngingasrembyong',
      'area': '4.1 Ha',
      'location': 'Desa Ngingasrembyong, Kec. Sooko, Kab. Mojokerto',
      'status': 'Aktif',
      'crop': 'Padi Hibrida',
      'farmer': 'Bu Darmi',
    },
  ];

  List<Map<String, dynamic>> get _filteredFields {
    return _fields.where((f) {
      final matchFilter = _selectedFilter == 'Semua' || f['status'] == _selectedFilter;
      final query = _searchCtrl.text.toLowerCase();
      final matchSearch = query.isEmpty ||
          f['name'].toString().toLowerCase().contains(query) ||
          f['farmer'].toString().toLowerCase().contains(query) ||
          f['location'].toString().toLowerCase().contains(query);
      return matchFilter && matchSearch;
    }).toList();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Aktif':
        return AdvantaColors.primaryGreen;
      case 'Tidak Aktif':
        return AdvantaColors.mutedGrey;
      case 'Belum Verifikasi':
        return Colors.orange;
      default:
        return AdvantaColors.mutedGrey;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final filtered = _filteredFields;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Lahan'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            tooltip: 'Filter',
            onPressed: () => _showFilterSheet(context, theme, isDark),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Cari lahan, petani, lokasi...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {});
                  },
                )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // Filter chips
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final f = _filters[i];
                final selected = _selectedFilter == f;
                return ChoiceChip(
                  label: Text(f),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedFilter = f),
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

          // Summary bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Icon(Icons.grass_outlined, size: 14, color: AdvantaColors.mutedGrey),
                const SizedBox(width: 4),
                Text(
                  '${filtered.length} lahan ditemukan',
                  style: AdvantaText.caption.copyWith(color: AdvantaColors.mutedGrey),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: _isLoading
                ? const AdvantaLoadingState(
                    title: 'Memuat data lahan',
                    subtitle: 'Menyiapkan daftar field',
                    icon: Icons.grass_rounded,
                  )
                : filtered.isEmpty
                ? _buildEmpty()
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: filtered.length,
              itemBuilder: (_, i) => _FieldCard(
                data: filtered[i],
                isDark: isDark,
                theme: theme,
                statusColor: _statusColor(filtered[i]['status']),
                onTap: () => _showFieldDetail(context, filtered[i], theme, isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.grass_outlined, size: 64, color: AdvantaColors.mutedGrey.withAlpha(80)),
          const SizedBox(height: 16),
          Text('Tidak ada lahan ditemukan',
              style: AdvantaText.body1.copyWith(color: AdvantaColors.mutedGrey)),
          const SizedBox(height: 8),
          Text('Coba ubah filter atau kata kunci pencarian',
              style: AdvantaText.caption.copyWith(color: AdvantaColors.mutedGrey)),
        ],
      ),
    );
  }

  void _showFilterSheet(BuildContext context, ThemeData theme, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: AdvantaRadius.sheetRadius),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filter Status', style: AdvantaText.heading2.copyWith(color: theme.colorScheme.onSurface)),
            const SizedBox(height: 16),
            ..._filters.map((f) => RadioListTile<String>(
              value: f,
              // ignore: deprecated_member_use
              groupValue: _selectedFilter,
              title: Text(f, style: AdvantaText.body1),
              // ignore: deprecated_member_use
              onChanged: (v) {
                setState(() => _selectedFilter = v!);
                Navigator.pop(ctx);
              },
            )),
          ],
        ),
      ),
    );
  }

  void _showFieldDetail(BuildContext context, Map<String, dynamic> data, ThemeData theme, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: AdvantaRadius.sheetRadius),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(data['name'], style: AdvantaText.heading2.copyWith(color: theme.colorScheme.onSurface)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(data['status']).withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    data['status'],
                    style: TextStyle(color: _statusColor(data['status']), fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _DetailRow(icon: Icons.tag, label: 'ID Lahan', value: data['id']),
            _DetailRow(icon: Icons.straighten, label: 'Luas', value: data['area']),
            _DetailRow(icon: Icons.location_on_outlined, label: 'Lokasi', value: data['location']),
            _DetailRow(icon: Icons.eco_outlined, label: 'Komoditas', value: data['crop']),
            _DetailRow(icon: Icons.person_outline, label: 'Petani', value: data['farmer']),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('TUTUP')),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isDark;
  final ThemeData theme;
  final Color statusColor;
  final VoidCallback onTap;

  const _FieldCard({
    required this.data,
    required this.isDark,
    required this.theme,
    required this.statusColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: AdvantaRadius.cardRadius,
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withAlpha(12),
        ),
      ),
      child: InkWell(
        borderRadius: AdvantaRadius.cardRadius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(isDark ? 40 : 20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.grass_outlined, color: theme.colorScheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['name'],
                        style: AdvantaText.bodyBold.copyWith(color: theme.colorScheme.onSurface),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(data['location'],
                        style: AdvantaText.caption.copyWith(color: AdvantaColors.mutedGrey),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withAlpha(25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(data['status'],
                              style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 8),
                        Text('• ${data['area']}',
                            style: AdvantaText.caption.copyWith(color: AdvantaColors.mutedGrey)),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AdvantaColors.mutedGrey.withAlpha(150)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AdvantaColors.mutedGrey),
          const SizedBox(width: 10),
          Text('$label:', style: AdvantaText.caption.copyWith(color: AdvantaColors.mutedGrey)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value,
                style: AdvantaText.bodyBold.copyWith(color: theme.colorScheme.onSurface, fontSize: 13),
                textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}
