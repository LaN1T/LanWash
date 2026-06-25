import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:file_saver/file_saver.dart';
import 'package:lanwash/app_styles.dart';
import 'package:lanwash/core/service_locator.dart';
import 'package:lanwash/models/user.dart';
import 'package:lanwash/models/washer_payroll_report.dart';
import 'package:lanwash/services/api_service.dart';
import 'package:lanwash/services/pdf_export_service.dart';
import 'package:lanwash/widgets/admin/report_date_picker_field.dart';
import 'package:lanwash/widgets/admin/report_dropdown_field.dart';
import 'package:lanwash/widgets/admin/report_filter_card.dart';
import 'package:lanwash/widgets/admin/report_summary_card.dart';
import 'package:lanwash/widgets/admin/report_summary_item.dart';
import 'package:lanwash/widgets/admin/report_table_card.dart';

class WasherPayrollReportScreen extends StatefulWidget {
  const WasherPayrollReportScreen({super.key});

  @override
  State<WasherPayrollReportScreen> createState() =>
      _WasherPayrollReportScreenState();
}

class _WasherPayrollReportScreenState extends State<WasherPayrollReportScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String? _washerUsername;
  bool _loading = false;
  WasherPayrollReport? _report;
  String? _error;
  List<User> _washers = [];

  @override
  void initState() {
    super.initState();
    _loadWashers();
    _load();
  }

  Future<void> _loadWashers() async {
    try {
      final washers = await sl<ApiService>().getWashers();
      if (!mounted) return;
      setState(() => _washers = washers);
    } catch (e) {
      if (kDebugMode) debugPrint('load washers error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось загрузить мойщиков')),
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
      final report = await sl<ApiService>().getWasherPayrollReport(
        startDate: _startDate,
        endDate: _endDate,
        washerUsername: _washerUsername,
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
    await PdfExportService.exportWasherPayrollReport(_report!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PDF экспортирован')),
    );
  }

  Future<void> _exportExcel() async {
    final params = <String, dynamic>{
      'start_date': DateFormat('yyyy-MM-dd').format(_startDate),
      'end_date': DateFormat('yyyy-MM-dd').format(_endDate),
      if (_washerUsername != null) 'washer_username': _washerUsername,
    };
    final bytes = await sl<ApiService>().downloadReportExcel(
      '/reports/washer-payroll/',
      params,
    );
    if (bytes == null) return;
    await FileSaver.instance.saveFile(
      name:
          'washer_payroll_${DateFormat('yyyy-MM-dd').format(_startDate)}_${DateFormat('yyyy-MM-dd').format(_endDate)}',
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
        title: const Text('Зарплата мойщиков',
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
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_report != null) ...[
                      ReportSummaryCard(
                        children: [
                          ReportSummaryItem(
                            label: 'Мойщиков',
                            value: '${_report!.items.length}',
                          ),
                          ReportSummaryItem(
                            label: 'Всего к выплате',
                            value:
                                '${_report!.items.fold<double>(0, (sum, e) => sum + e.total).toStringAsFixed(0)} ₽',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ReportTableCard(
                        title: 'Детализация',
                        columns: const [
                          DataColumn(label: Text('Мойщик')),
                          DataColumn(label: Text('Записей')),
                          DataColumn(label: Text('Услуги')),
                          DataColumn(label: Text('Чаевые')),
                          DataColumn(label: Text('Итого')),
                        ],
                        rows: _report!.items
                            .map((e) => DataRow(cells: [
                                  DataCell(Text(e.washerName)),
                                  DataCell(Text('${e.appointmentsCount}')),
                                  DataCell(Text(
                                      '${e.servicesTotal.toStringAsFixed(0)} ₽')),
                                  DataCell(Text(
                                      '${e.tipsTotal.toStringAsFixed(0)} ₽')),
                                  DataCell(
                                      Text('${e.total.toStringAsFixed(0)} ₽')),
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
