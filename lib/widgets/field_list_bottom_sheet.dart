// lib/widgets/field_list_bottom_sheet.dart
//
// FIELD LIST BOTTOM SHEET — Tampilan daftar lahan sebagai bottom sheet
// ─────────────────────────────────────────────────────────────────────
// • Terpisah dari qa_screen.dart agar tidak ada konflik logika
// • Membaca data langsung dari parsedMapFieldsProvider
// • TIDAK mengandung warning card "lahan tanpa koordinat"
// • Muncul dari bawah seperti FieldDetailBottomSheet
// • Mendukung sort by jarak dari lokasi user
// ─────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/master_fields_provider.dart';
import '../theme/app_theme.dart';
import 'field_detail_bottom_sheet.dart';

// ─── Entry-point statis (seperti FieldDetailBottomSheet.show) ────────
class FieldListBottomSheet {
  static void show(
    BuildContext context, {
    LatLng? userLocation,
    List<ParsedFieldData>? fields, // opsional: jika null, baca dari provider
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => _FieldListBottomSheetBody(
        userLocation: userLocation,
        overrideFields: fields,
      ),
    );
  }
}

// ─── Body Widget ──────────────────────────────────────────────────────
class _FieldListBottomSheetBody extends ConsumerStatefulWidget {
  final LatLng? userLocation;
  final List<ParsedFieldData>? overrideFields;

  const _FieldListBottomSheetBody({
    this.userLocation,
    this.overrideFields,
  });

  @override
  ConsumerState<_FieldListBottomSheetBody> createState() =>
      _FieldListBottomSheetBodyState();
}

class _FieldListBottomSheetBodyState
    extends ConsumerState<_FieldListBottomSheetBody> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ─── Warna fase DAP ──────────────────────────────────────────
  static const _phaseColors = [
    Color(0xFF78909C), // Vegetative   ≤45 DAP
    Color(0xFFFFCA28), // Generative1  46-54
    Color(0xFFFF7043), // Generative2  55-59
    Color(0xFFE53935), // Generative3  60-75
    Color(0xFF795548), // Pre-Harvest  76-100
    Color(0xFF43A047), // Harvest      >100
  ];

  Color _markerColor(int dap) {
    if (dap <= 45) return _phaseColors[0];
    if (dap <= 54) return _phaseColors[1];
    if (dap <= 59) return _phaseColors[2];
    if (dap <= 75) return _phaseColors[3];
    if (dap <= 100) return _phaseColors[4];
    return _phaseColors[5];
  }

  Future<void> _openInGoogleMaps(double lat, double lng) async {
    final url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  // ─── Filter + Sort ───────────────────────────────────────────
  List<({ParsedFieldData data, double distance})> _buildSortedItems(
      List<ParsedFieldData> allFields) {
    // 1. Filter berdasarkan search query (field_number atau farmer_name)
    final query = _searchQuery.trim().toLowerCase();
    final filtered = query.isEmpty
        ? allFields
        : allFields.where((f) {
            final fn =
                f.raw['field_number']?.toString().toLowerCase() ?? '';
            final name =
                f.raw['farmer_name']?.toString().toLowerCase() ?? '';
            return fn.contains(query) || name.contains(query);
          }).toList();

    // 2. Hitung jarak untuk semua lahan
    final items = filtered.map((f) {
      double dist = 0;
      if (widget.userLocation != null && !f.isDefault) {
        dist = Geolocator.distanceBetween(
          widget.userLocation!.latitude,
          widget.userLocation!.longitude,
          f.lat,
          f.lng,
        );
      }
      return (data: f, distance: dist);
    }).toList();

    // 3. Sort: yang ada koordinat → terdekat; tanpa koordinat → paling bawah
    items.sort((a, b) {
      if (!a.data.isDefault && !b.data.isDefault) {
        return a.distance.compareTo(b.distance);
      }
      if (!a.data.isDefault && b.data.isDefault) return -1;
      if (a.data.isDefault && !b.data.isDefault) return 1;
      return 0;
    });

    return items;
  }

  @override
  Widget build(BuildContext context) {
    // Ambil data: dari override (sudah difilter oleh qa_screen) ATAU
    // langsung dari provider (seluruh data tanpa filter tambahan)
    final parsedAsync = ref.watch(parsedMapFieldsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: AdvantaColors.deepForest,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // ── Drag handle ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AdvantaColors.goldLight.withAlpha(46),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Header ───────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AdvantaColors.primaryGreen.withAlpha(51),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.format_list_bulleted_rounded,
                        color: AdvantaColors.lightGreen,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: parsedAsync.when(
                        data: (all) {
                          final source = widget.overrideFields ?? all;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Daftar Lahan',
                                style: AdvantaText.heading3
                                    .copyWith(color: Colors.white),
                              ),
                              Text(
                                '${source.length} lahan tersedia',
                                style: AdvantaText.caption
                                    .copyWith(color: Colors.white54),
                              ),
                            ],
                          );
                        },
                        loading: () => Text(
                          'Daftar Lahan',
                          style: AdvantaText.heading3
                              .copyWith(color: Colors.white),
                        ),
                        error: (_, __) => Text(
                          'Daftar Lahan',
                          style: AdvantaText.heading3
                              .copyWith(color: Colors.white),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.close,
                            color: Colors.white54, size: 16),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Search bar ───────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withAlpha(22)),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    style: AdvantaText.body2.copyWith(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Cari nomor lahan atau nama petani…',
                      hintStyle: AdvantaText.caption
                          .copyWith(color: Colors.white38),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: Colors.white38, size: 18),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              },
                              child: const Icon(Icons.close,
                                  color: Colors.white38, size: 16),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
              ),

              Divider(
                  color: AdvantaColors.goldLight.withAlpha(20), height: 1),

              // ── List ─────────────────────────────────────────
              Expanded(
                child: parsedAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color: AdvantaColors.lightGreen,
                    ),
                  ),
                  error: (e, _) => Center(
                    child: Text(
                      'Gagal memuat data: $e',
                      style: AdvantaText.body2
                          .copyWith(color: AdvantaColors.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  data: (allParsed) {
                    // Gunakan override jika ada, atau seluruh data dari provider
                    final source = widget.overrideFields ?? allParsed;
                    final items = _buildSortedItems(source);

                    if (items.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              color: Colors.white24,
                              size: 40,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Tidak ada lahan ditemukan',
                              style: AdvantaText.body2
                                  .copyWith(color: Colors.white38),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.only(top: 8, bottom: 32),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => Divider(
                        color: AdvantaColors.goldLight.withAlpha(15),
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                      ),
                      itemBuilder: (_, i) {
                        final item = items[i];
                        final f = item.data;
                        final fn =
                            f.raw['field_number']?.toString() ?? '';
                        final phaseColor = f.isDefault
                            ? AdvantaColors.error
                            : _markerColor(f.dap);

                        final distKm =
                            (item.distance / 1000).toStringAsFixed(1);
                        final distM = item.distance.toInt();

                        return GestureDetector(
                          onTap: () {
                            Navigator.pop(ctx);
                            FieldDetailBottomSheet.show(
                              context,
                              f.raw,
                              onInspectDone: (fieldData) {
                                FieldDetailBottomSheet.show(
                                    context, fieldData);
                              },
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color.alphaBlend(
                                      phaseColor.withAlpha(60),
                                      AdvantaColors.deepForest),
                                  AdvantaColors.deepForest,
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: AdvantaRadius.cardRadius,
                              border: Border.all(
                                color: phaseColor.withAlpha(80),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: phaseColor.withAlpha(25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.stretch,
                              children: [
                                // ── Strip aksen warna kiri ──
                                Container(
                                  width: 4,
                                  decoration: BoxDecoration(
                                    color: phaseColor,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(12),
                                      bottomLeft: Radius.circular(12),
                                    ),
                                  ),
                                ),
                                // ── Konten ──
                                Expanded(
                                  child: ListTile(
                                    contentPadding:
                                        const EdgeInsets.all(12),
                                    leading: _buildDapAvatar(
                                        f.dap, phaseColor),
                                    title: Text(
                                      fn,
                                      style: AdvantaText.bodyBold
                                          .copyWith(color: Colors.white),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          f.raw['farmer_name'] ?? '-',
                                          style: AdvantaText.caption
                                              .copyWith(
                                                  color: Colors.white70),
                                        ),
                                        const SizedBox(height: 4),
                                        if (f.isDefault)
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons
                                                    .location_off_rounded,
                                                size: 12,
                                                color: AdvantaColors.error,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Tanpa Koordinat',
                                                style: AdvantaText.caption
                                                    .copyWith(
                                                  color:
                                                      AdvantaColors.error,
                                                  fontWeight:
                                                      FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          )
                                        else
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.near_me_rounded,
                                                size: 12,
                                                color:
                                                    AdvantaColors.goldLight,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                item.distance > 1000
                                                    ? '$distKm km'
                                                    : '$distM m',
                                                style: AdvantaText.caption
                                                    .copyWith(
                                                  color:
                                                      AdvantaColors.goldLight,
                                                  fontWeight:
                                                      FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                ' dari lokasi Anda',
                                                style: AdvantaText.caption
                                                    .copyWith(
                                                        color:
                                                            Colors.white38),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                    trailing: f.isDefault
                                        ? const Icon(
                                            Icons
                                                .edit_location_alt_outlined,
                                            color: AdvantaColors.error,
                                            size: 20,
                                          )
                                        : IconButton(
                                            icon: const Icon(
                                              Icons.directions_outlined,
                                              color:
                                                  AdvantaColors.lightGreen,
                                              size: 20,
                                            ),
                                            onPressed: () =>
                                                _openInGoogleMaps(
                                                    f.lat, f.lng),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDapAvatar(int dap, Color color) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Center(
        child: Text(
          '$dap',
          style: AdvantaText.label.copyWith(color: color),
        ),
      ),
    );
  }
}
