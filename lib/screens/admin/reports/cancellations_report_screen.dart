import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:file_saver/file_saver.dart';
import 'package:lanwash/app_styles.dart';
import 'package:lanwash/core/service_locator.dart';
import 'package:lanwash/models/cancellations_report.dart';
import 'package:lanwash/models/user.dart';
import 'package:lanwash/models/wash_type.dart';
import 'package:lanwash/services/api_service.dart';
import 'package:lanwash/services/pdf_export_service.dart';
import 'package:lanwash/widgets/admin/report_date_picker_field.dart';
import 'package:lanwash/widgets/admin/report_dropdown_field.dart';
import 'package:lanwash/widgets/admin/report_filter_card.dart';
import 'package:lanwash/widgets/admin/report_summary_card.dart';
import 'package:lanwash/widgets/admin/report_summary_item.dart';
import 'package:lanwash/widgets/admin/report_table_card.dart';

class CancellationsReportScreen extends StatefulWidget {
  const CancellationsReportScreen({super.key});

  @override
  State<CancellationsReportScreen> createState() =>
      _CancellationsReportScreenState();
}

class _CancellationsReportScreenState extends State<CancellationsReportScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String? _reason;
  String? _washerUsername;
  String? _washTypeId;
  bool _loading = false;
  CancellationsReport? _report;
  String? _error;
  List<User> _washers = [];
  List<WashType> _washTypes = [];

  @override
  void initState() {
    super.initState();
    _loadReferences();
    _load();
  }

  Future<void> _loadReferences() async {
    try {
      final api = sl<ApiService>();
      final results = await Future.wait([
        api.getWashers(),
        api.getWashTypes(),
      ]);
      if (!mounted) return;
      setState(() {
        _washers = results[0] as List<User>;
        _washTypes = results[1] as List<WashType>;
      });
    } catch (e) {
      if (kDebugMode) debugPrint('load references error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось загрузить справочники')),
        );
      }
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _report = null;
    });
    try {
      final report = await sl<ApiService>().getCancellationsReport(
        startDate: _startDate,
        endDate: _endDate,
        reason: _reason,
        washerUsername: _washerUsername,
        washTypeId: _washTypeId,
      );
      if (!mounted) return;
      setState(() => _report = report);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Не удалось загрузить отчёт: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _exportPdf() async {
    if (_report == null) return;
    await PdfExportService.exportCancellationsReport(_report!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PDF экспортирован')),
    );
  }

  Future<void> _exportExcel() async {
    final params = <String, dynamic>{
      'start_date': DateFormat('yyyy-MM-dd').format(_startDate),
      'end_date': DateFormat('yyyy-MM-dd').format(_endDate),
      if (_reason != null && _reason!.isNotEmpty) 'reason': _reason,
      if (_washerUsername != null) 'washer_username': _washerUsername,
      if (_washTypeId != null) 'wash_type_id': _washTypeId,
    };
    final bytes = await sl<ApiService>().downloadReportExcel(
      '/reports/cancellations/',
      params,
    );
    if (bytes == null) return;
    await FileSaver.instance.saveFile(
      name:
          'cancellations_${DateFormat('yyyy-MM-dd').format(_startDate)}_${DateFormat('yyyy-MM-dd').format(_endDate)}',
      bytes: bytes,
      mimeType: MimeType.microsoftExcel,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Excel экспортирован')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Отмены и возвраты',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppStyles.adaptiveBorder(context)),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style: const TextStyle(
                          color: AppStyles.danger, fontSize: 16)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    ReportFilterCard(
                      onApply: _load,
                      children: [
                        SizedBox(
                          width: 160,
                          child: ReportDatePickerField(
                            label: 'С',
                            selectedDate: _startDate,
                            onChanged: (d) => setState(() => _startDate = d),
                          ),
                        ),
                        SizedBox(
                          width: 160,
                          child: ReportDatePickerField(
                            label: 'По',
                            selectedDate: _endDate,
                            onChanged: (d) => setState(() => _endDate = d),
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: TextFormField(
                            initialValue: _reason,
                            decoration: AppStyles.inputDecorationFor(
                                context, 'Причина'),
                            onChanged: (v) => _reason = v.isEmpty ? null : v,
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: ReportDropdownField<String?>(
                            label: 'Мойщик',
                            value: _washerUsername,
                            items: [
                              const DropdownMenuItem(
                                  value: null, child: Text('Все')),
                              ..._washers.map((w) => DropdownMenuItem(
                                  value: w.username,
                                  child: Text(w.displayName.isNotEmpty
                                      ? w.displayName
                                      : w.username))),
                            ],
                            onChanged: (v) =>
                                setState(() => _washerUsername = v),
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: ReportDropdownField<String?>(
                            label: 'Тип мойки',
                            value: _washTypeId,
                            items: [
                              const DropdownMenuItem(
                                  value: null, child: Text('Все')),
                              ..._washTypes.map((t) => DropdownMenuItem(
                                  value: t.id, child: Text(t.name))),
                            ],
                            onChanged: (v) => setState(() => _washTypeId = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_report != null) ...[
                      ReportSummaryCard(
                        children: [
                          ReportSummaryItem(
                            label: 'Отмен',
                            value:
                                '${(_report!.summary['total_cancellations'] as num?)?.toInt() ?? 0}',
                          ),
                          ReportSummaryItem(
                            label: 'Потеря',
                            value:
                                '${(_report!.summary['lost_revenue'] as num?)?.toStringAsFixed(0) ?? '0'} ₽',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ReportTableCard(
                        title: 'Детализация',
                        columns: const [
                          DataColumn(label: Text('Дата')),
                          DataColumn(label: Text('Клиент')),
                          DataColumn(label: Text('Авто')),
                          DataColumn(label: Text('Причина')),
                          DataColumn(label: Text('Кем отменено')),
                          DataColumn(label: Text('Потеря')),
                        ],
                        rows: _report!.items
                            .map((e) => DataRow(cells: [
                                  DataCell(Text(
                                      DateFormat('dd.MM.yyyy').format(e.date))),
                                  DataCell(Text(e.clientName)),
                                  DataCell(Text(e.carModel)),
                                  DataCell(Text(e.reason ?? '-')),
                                  DataCell(Text(e.cancelledBy)),
                                  DataCell(Text(
                                      '${e.lostRevenue.toStringAsFixed(0)} ₽')),
                                ]))
                            .toList(),
                        onExportPdf: _exportPdf,
                        onExportExcel: _exportExcel,
                      ),
                    ],
                  ],
                ),
    );
  }
}
