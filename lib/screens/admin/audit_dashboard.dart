// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuditDashboard extends StatefulWidget {
  const AuditDashboard({super.key});

  @override
  State<AuditDashboard> createState() => _AuditDashboardState();
}

class _AuditDashboardState extends State<AuditDashboard> {
  static const _datasetName = 'psp_vegetative_audit';
  static const _datasetVersion = 1;
  static const _tableName = 'audit_vegetative';
  static const _pageSize = 1000;

  static const List<String> _masterCsvColumns = [
    'field_number',
    'region',
    'territory',
    'sub_region',
    'area',
    'season',
    'hybrid',
    'farmer',
    'village_desa',
    'sub_district_kec',
    'district_kab',
    'effective_area_ha',
    'planting_date_pdn',
    'qa_fi',
    'qa_spv',
  ];

  static const List<String> _auditColumns = [
    'field_number',
    'date_of_audit',
    'audit_date_user',
    'audit_week',
    'qa_fi',
    'qa_spv',
    'correction_tagging',
    'co_detasseling',
    'field_size_by_audit_ha',
    'previous_crop_by_audit',
    'type_seed',
    'isolation_problem_by_audit',
    'rev_planting_date',
    'crop_health',
    'crop_uniformity',
    'roguing_status',
    'offtype_in_male',
    'offtype_in_female',
    'lsv_status',
    'decision',
    'pld_reason',
    'flagging',
    'remarks',
    'fase',
    'recommendation_pld_ha',
    'is_mass_submit',
    'updated_at',
    'date_of_inspeksi_roguing_1',
    'audit_offtype_roguing_1',
    'audit_volunteer_roguing_1',
    'crop_health_roguing_1',
    'crop_uniformity_roguing_1',
    'isolation_audit_roguing_1',
    'isolation_type_roguing_1',
    'isolation_distance_roguing_1',
    'date_of_inspeksi_roguing_2',
    'audit_offtype_roguing_2',
    'audit_volunteer_roguing_2',
    'audit_lsv_roguing_2',
    'crop_health_roguing_2',
    'crop_uniformity_roguing_2',
    'date_of_inspeksi_roguing_3',
    'audit_offtype_roguing_3',
    'audit_volunteer_roguing_3',
    'audit_lsv_roguing_3',
    'crop_health_roguing_3',
    'crop_uniformity_roguing_3',
    'date_of_inspeksi_roguing_4',
    'audit_offtype_roguing_4',
    'audit_volunteer_roguing_4',
    'audit_lsv_roguing_4',
    'crop_health_roguing_4',
    'crop_uniformity_roguing_4',
    'isolation_audit_roguing_4',
    'isolation_type_roguing_4',
    'isolation_distance_roguing_4',
  ];

  final _supabase = Supabase.instance.client;
  final _dateFormatter = DateFormat('yyyyMMdd_HHmmss');

  bool _isLoading = false;
  String? _loadingStatus;
  String? _error;
  String? _lastAction;
  int _pspFieldCount = 0;
  int _pspAuditCount = 0;
  DateTime? _lastUpdatedAt;
  Set<String> _knownPspFieldNumbers = {};

  @override
  void initState() {
    super.initState();
    _refreshDatabaseSummary();
  }

  Future<void> _refreshDatabaseSummary() async {
    setState(() {
      _isLoading = true;
      _loadingStatus = 'Membaca ringkasan database PS/PSP...';
      _error = null;
    });

    try {
      final records = await _fetchPspVegetativeRecords(includeEmptyAudit: true);
      final audited = records.where((record) => record.audit.isNotEmpty).length;
      DateTime? lastUpdated;

      for (final record in records) {
        final raw = record.audit['updated_at'];
        if (raw == null) continue;
        final parsed = DateTime.tryParse(raw.toString());
        if (parsed == null) continue;
        if (lastUpdated == null || parsed.isAfter(lastUpdated)) {
          lastUpdated = parsed;
        }
      }

      if (!mounted) return;
      setState(() {
        _pspFieldCount = records.length;
        _pspAuditCount = audited;
        _lastUpdatedAt = lastUpdated;
        _knownPspFieldNumbers =
            records.map((record) => record.fieldNumber).toSet();
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal membaca database: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingStatus = null;
        });
      }
    }
  }

  Future<void> _exportPspVegetativeJson() async {
    await _runOperation(
      status: 'Menyiapkan backup JSON PS/PSP Vegetative...',
      action: () async {
        final records = await _fetchPspVegetativeRecords();
        if (records.isEmpty) {
          throw Exception('Belum ada audit PS/PSP vegetative untuk diexport.');
        }

        final payload = {
          'dataset': _datasetName,
          'schema_version': _datasetVersion,
          'table': _tableName,
          'exported_at': DateTime.now().toIso8601String(),
          'record_count': records.length,
          'records': records
              .map((record) => {
                    'field_number': record.fieldNumber,
                    'master': record.master,
                    'audit': _compactAudit(record.audit),
                  })
              .toList(),
        };

        final fileName =
            'psp_vegetative_audit_${_dateFormatter.format(DateTime.now())}.json';
        final jsonText = const JsonEncoder.withIndent('  ').convert(payload);
        final saved = await _saveBytes(
          fileName: fileName,
          bytes: utf8.encode(jsonText),
          allowedExtensions: const ['json'],
        );

        if (saved) {
          setState(() {
            _lastAction = 'Export JSON: ${records.length} record';
          });
          _showSnack('Export JSON selesai: ${records.length} record.');
        }
      },
    );
  }

  Future<void> _exportPspVegetativeCsv() async {
    await _runOperation(
      status: 'Menyiapkan file CSV PS/PSP Vegetative...',
      action: () async {
        final records = await _fetchPspVegetativeRecords();
        if (records.isEmpty) {
          throw Exception('Belum ada audit PS/PSP vegetative untuk diexport.');
        }

        final headers = <String>[
          ..._masterCsvColumns.map((column) => 'master_$column'),
          ..._auditColumns.map((column) => 'audit_$column'),
        ];
        final rows = <List<dynamic>>[
          headers,
          ...records.map((record) {
            final audit = _compactAudit(record.audit);
            return [
              ..._masterCsvColumns
                  .map((column) => _csvValue(record.master[column])),
              ..._auditColumns.map((column) => _csvValue(audit[column])),
            ];
          }),
        ];

        final csvText = const ListToCsvConverter().convert(rows);
        final fileName =
            'psp_vegetative_audit_${_dateFormatter.format(DateTime.now())}.csv';
        final saved = await _saveBytes(
          fileName: fileName,
          bytes: utf8.encode(csvText),
          allowedExtensions: const ['csv'],
        );

        if (saved) {
          setState(() {
            _lastAction = 'Export CSV: ${records.length} record';
          });
          _showSnack('Export CSV selesai: ${records.length} record.');
        }
      },
    );
  }

  Future<void> _importPspVegetativeJson() async {
    await _runOperation(
      status: 'Membaca file JSON import...',
      action: () async {
        final result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['json'],
          withData: true,
        );
        if (result == null || result.files.isEmpty) return;

        final bytes = result.files.first.bytes;
        if (bytes == null) {
          throw Exception('File tidak dapat dibaca. Pilih ulang file JSON.');
        }

        final parsed = jsonDecode(utf8.decode(bytes));
        final importPayload = await _extractImportRows(parsed);
        if (importPayload.rows.isEmpty) {
          throw Exception('Tidak ada record audit valid di file JSON.');
        }

        final confirmed = await _confirmImport(importPayload.rows.length);
        if (!confirmed) return;

        setState(() => _loadingStatus = 'Mengirim data ke audit_vegetative...');
        final imported = await _upsertVegetativeRows(importPayload.rows);
        final resultSummary = _ImportSummary(
          imported: imported,
          skipped: importPayload.skipped,
        );

        await _refreshDatabaseSummary();
        if (!mounted) return;
        setState(() {
          _lastAction =
              'Import JSON: ${resultSummary.imported} masuk, ${resultSummary.skipped} dilewati';
        });
        _showSnack(
          'Import selesai: ${resultSummary.imported} record masuk, '
          '${resultSummary.skipped} dilewati.',
        );
      },
    );
  }

  Future<List<_PspVegetativeExportRecord>> _fetchPspVegetativeRecords({
    bool includeEmptyAudit = false,
  }) async {
    final records = <_PspVegetativeExportRecord>[];
    var from = 0;

    while (true) {
      final response = await _supabase
          .from('master_fields')
          .select('*, audit_vegetative(*)')
          .eq('is_active', true)
          .ilike('hybrid', 'ASF%')
          .order('field_number', ascending: true)
          .range(from, from + _pageSize - 1);

      final rows = List<Map<String, dynamic>>.from(response);
      for (final row in rows) {
        final audit = _firstAudit(row['audit_vegetative']);
        if (!includeEmptyAudit && audit == null) continue;

        final master = Map<String, dynamic>.from(row);
        master.remove('audit_vegetative');
        records.add(
          _PspVegetativeExportRecord(
            fieldNumber: master['field_number']?.toString() ?? '',
            master: _jsonSafeMap(master),
            audit: audit == null ? {} : _jsonSafeMap(audit),
          ),
        );
      }

      if (rows.length < _pageSize) break;
      from += _pageSize;
    }

    return records
        .where((record) => record.fieldNumber.trim().isNotEmpty)
        .toList();
  }

  Map<String, dynamic>? _firstAudit(dynamic raw) {
    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return Map<String, dynamic>.from(raw.first as Map);
    }
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  Map<String, dynamic> _compactAudit(Map<String, dynamic> audit) {
    final compact = <String, dynamic>{};
    for (final column in _auditColumns) {
      if (audit.containsKey(column)) {
        compact[column] = _jsonSafe(audit[column]);
      }
    }
    return compact;
  }

  Map<String, dynamic> _jsonSafeMap(Map<String, dynamic> raw) {
    return raw.map((key, value) => MapEntry(key, _jsonSafe(value)));
  }

  dynamic _jsonSafe(dynamic value) {
    if (value is DateTime) return value.toIso8601String();
    if (value is Map) {
      return value
          .map((key, inner) => MapEntry(key.toString(), _jsonSafe(inner)));
    }
    if (value is List) return value.map(_jsonSafe).toList();
    return value;
  }

  String _csvValue(dynamic value) {
    if (value == null) return '';
    if (value is Map || value is List) return jsonEncode(value);
    return value.toString();
  }

  Future<_ImportExtractResult> _extractImportRows(dynamic parsed) async {
    final rawRecords = <dynamic>[];
    if (parsed is Map<String, dynamic>) {
      final dataset = parsed['dataset']?.toString();
      if (dataset != null && dataset != _datasetName) {
        throw Exception('Dataset JSON bukan $_datasetName.');
      }
      final records = parsed['records'];
      if (records is List) rawRecords.addAll(records);
    } else if (parsed is List) {
      rawRecords.addAll(parsed);
    }

    if (_knownPspFieldNumbers.isEmpty) {
      final records = await _fetchPspVegetativeRecords(includeEmptyAudit: true);
      _knownPspFieldNumbers =
          records.map((record) => record.fieldNumber).toSet();
    }

    final rows = <Map<String, dynamic>>[];
    var skipped = 0;
    for (final rawRecord in rawRecords) {
      if (rawRecord is! Map) {
        skipped++;
        continue;
      }
      final rawMap = Map<String, dynamic>.from(rawRecord);
      final rawAudit = rawMap['audit'] is Map
          ? Map<String, dynamic>.from(rawMap['audit'] as Map)
          : rawMap;
      final audit = _compactAudit(rawAudit);
      final fieldNumber =
          (audit['field_number'] ?? rawMap['field_number'])?.toString().trim();
      if (fieldNumber == null || fieldNumber.isEmpty) {
        skipped++;
        continue;
      }
      if (!_knownPspFieldNumbers.contains(fieldNumber)) {
        skipped++;
        continue;
      }

      audit['field_number'] = fieldNumber;
      audit['updated_at'] = DateTime.now().toIso8601String();
      rows.add(audit);
    }

    return _ImportExtractResult(rows: rows, skipped: skipped);
  }

  Future<int> _upsertVegetativeRows(
    List<Map<String, dynamic>> rows,
  ) async {
    var imported = 0;
    const chunkSize = 200;

    for (var i = 0; i < rows.length; i += chunkSize) {
      final end = (i + chunkSize > rows.length) ? rows.length : i + chunkSize;
      final chunk = rows.sublist(i, end);
      await _supabase
          .from(_tableName)
          .upsert(chunk, onConflict: 'field_number');
      imported += chunk.length;
    }

    return imported;
  }

  Future<bool> _saveBytes({
    required String fileName,
    required List<int> bytes,
    required List<String> allowedExtensions,
  }) async {
    final path = await FilePicker.saveFile(
      dialogTitle: 'Simpan $fileName',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      bytes: Uint8List.fromList(bytes),
    );
    return path != null;
  }

  Future<void> _runOperation({
    required String status,
    required Future<void> Function() action,
  }) async {
    setState(() {
      _isLoading = true;
      _loadingStatus = status;
      _error = null;
    });

    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
        _showSnack(e.toString(), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingStatus = null;
        });
      }
    }
  }

  Future<bool> _confirmImport(int count) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Import'),
        content: Text(
          'Import akan upsert $count record ke tabel audit_vegetative untuk '
          'PS/PSP vegetative. Data dengan field_number yang sama akan diperbarui.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('Import'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              isError ? Colors.red.shade700 : Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final lastUpdatedText = _lastUpdatedAt == null
        ? '-'
        : DateFormat('dd MMM yyyy HH:mm').format(_lastUpdatedAt!.toLocal());

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshDatabaseSummary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isLoading) _buildLoadingBanner(),
                    if (_error != null) _buildErrorBanner(_error!),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 760;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _buildMetricCard(
                              width: isWide ? 220 : constraints.maxWidth,
                              title: 'PS/PSP Fields',
                              value: _pspFieldCount.toString(),
                              icon: Icons.inventory_2_outlined,
                              color: const Color(0xFF00796B),
                            ),
                            _buildMetricCard(
                              width: isWide ? 220 : constraints.maxWidth,
                              title: 'Vegetative Audits',
                              value: _pspAuditCount.toString(),
                              icon: Icons.fact_check_outlined,
                              color: const Color(0xFF1565C0),
                            ),
                            _buildMetricCard(
                              width: isWide ? 260 : constraints.maxWidth,
                              title: 'Last DB Update',
                              value: lastUpdatedText,
                              icon: Icons.update_rounded,
                              color: const Color(0xFF6A1B9A),
                              compactText: true,
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    _buildDatasetPanel(),
                    const SizedBox(height: 18),
                    _buildImportRulesPanel(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade800, const Color(0xFF00695C)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () {
                if (kIsWeb) {
                  Navigator.of(context).pop();
                } else {
                  context.go('/admin');
                }
              },
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Database Export/Import',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Audit Analysis difokuskan untuk backup dan restore database audit.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: _isLoading ? null : _refreshDatabaseSummary,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _loadingStatus ?? 'Memproses database...',
              style: TextStyle(color: Colors.grey.shade800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.red.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.red.shade800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required double width,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    bool compactText = false,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withAlpha(12)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withAlpha(22),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: compactText ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade900,
                    fontSize: compactText ? 14 : 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatasetPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withAlpha(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00796B).withAlpha(22),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.table_view_rounded,
                  color: Color(0xFF00796B),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PS/PSP Vegetative Audit',
                      style: TextStyle(
                        color: Colors.grey.shade900,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Sumber: master_fields hybrid ASF* dan relasi audit_vegetative.',
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildActionButton(
                label: 'Export JSON',
                icon: Icons.file_download_outlined,
                color: const Color(0xFF00796B),
                onPressed: _isLoading ? null : _exportPspVegetativeJson,
              ),
              _buildActionButton(
                label: 'Export CSV',
                icon: Icons.grid_on_rounded,
                color: const Color(0xFF1565C0),
                onPressed: _isLoading ? null : _exportPspVegetativeCsv,
              ),
              _buildActionButton(
                label: 'Import JSON',
                icon: Icons.upload_file_rounded,
                color: const Color(0xFFEF6C00),
                onPressed: _isLoading ? null : _importPspVegetativeJson,
              ),
            ],
          ),
          if (_lastAction != null) ...[
            const SizedBox(height: 14),
            Text(
              _lastAction!,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 42,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _buildImportRulesPanel() {
    final columnsText = _auditColumns.take(12).join(', ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withAlpha(10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Format database',
            style: TextStyle(
              color: Colors.grey.shade900,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'JSON adalah backup yang bisa diimport kembali. CSV dibuat untuk '
            'review dan olah data di spreadsheet.',
            style: TextStyle(color: Colors.grey.shade700, height: 1.4),
          ),
          const SizedBox(height: 8),
          Text(
            'Kolom audit utama: $columnsText, dan detail roguing 1 sampai 4.',
            style: TextStyle(
                color: Colors.grey.shade600, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _PspVegetativeExportRecord {
  final String fieldNumber;
  final Map<String, dynamic> master;
  final Map<String, dynamic> audit;

  const _PspVegetativeExportRecord({
    required this.fieldNumber,
    required this.master,
    required this.audit,
  });
}

class _ImportSummary {
  final int imported;
  final int skipped;

  const _ImportSummary({
    required this.imported,
    required this.skipped,
  });
}

class _ImportExtractResult {
  final List<Map<String, dynamic>> rows;
  final int skipped;

  const _ImportExtractResult({
    required this.rows,
    required this.skipped,
  });
}
