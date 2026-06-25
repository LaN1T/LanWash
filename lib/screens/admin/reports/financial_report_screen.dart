import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:file_saver/file_saver.dart';
import 'package:lanwash/app_styles.dart';
import 'package:lanwash/core/service_locator.dart';
import 'package:lanwash/models/financial_report.dart';
import 'package:lanwash/models/promo.dart';
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

class FinancialReportScreen extends StatefulWidget {
  const FinancialReportScreen({super.key});

  @override
  State<FinancialReportScreen> createState() => _FinancialReportScreenState();
}

class _FinancialReportScreenState extends State<FinancialReportScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String _groupBy = 'day';
  String? _washerUsername;
  String? _washTypeId;
  String? _promoId;
  bool _loading = false;
  FinancialReport? _report;
  String? _error;

  List<User> _washers = [];
  List<WashType> _washTypes = [];
  List<Promo> _promos = [];

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
        api.getPromos(),
      ]);
      if (!mounted) return;
      setState(() {
        _washers = results[0] as List<User>;
        _washTypes = results[1] as List<WashType>;
        _promos = results[2] as List<Promo>;
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
      final api = sl<ApiService>();
      final report = await api.getFinancialReport(
        startDate: _startDate,
        endDate: _endDate,
        groupBy: _groupBy,
        washerUsername: _washerUsername,
        washTypeId: _washTypeId,
        promoId: _promoId,
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
    await PdfExportService.exportFinancialReport(_report!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PDF экспортирован')),
    );
  }

  Future<void> _exportExcel() async {
    final params = <String, dynamic>{
      'start_date': DateFormat('yyyy-MM-dd').format(_startDate),
      'end_date': DateFormat('yyyy-MM-dd').format(_endDate),
      'group_by': _groupBy,
      if (_washerUsername != null) 'washer_username': _washerUsername,
      if (_washTypeId != null) 'wash_type_id': _washTypeId,
      if (_promoId != null) 'promo_id': _promoId,
    };
    final bytes = await sl<ApiService>().downloadReportExcel(
      '/reports/financial/',
      params,
    );
    if (bytes == null) return;
    await FileSaver.instance.saveFile(
      name:
          'financial_${DateFormat('yyyy-MM-dd').format(_startDate)}_${DateFormat('yyyy-MM-dd').format(_endDate)}',
      bytes: bytes,
      mimeType: MimeType.microsoftExcel,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Excel экспортирован')),
    );
  }

  String get _avgCheck {
    if (_report == null) return '0 ₽';
    final revenue = _report!.summary['revenue'] ?? 0;
    final count = _report!.summary['appointments_count'] ?? 0;
    if (count <= 0) return '0 ₽';
    return '${(revenue / count).toStringAsFixed(0)} ₽';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Финансовый отчёт',
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
                          child: ReportDropdownField<String>(
                            label: 'Группировка',
                            value: _groupBy,
                            items: const [
                              DropdownMenuItem(
                                  value: 'day', child: Text('День')),
                              DropdownMenuItem(
                                  value: 'week', child: Text('Неделя')),
                              DropdownMenuItem(
                                  value: 'month', child: Text('Месяц')),
                            ],
                            onChanged: (v) =>
                                setState(() => _groupBy = v ?? 'day'),
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
                        SizedBox(
                          width: 220,
                          child: ReportDropdownField<String?>(
                            label: 'Акция',
                            value: _promoId,
                            items: [
                              const DropdownMenuItem(
                                  value: null, child: Text('Все')),
                              ..._promos.map((p) => DropdownMenuItem(
                                  value: p.id, child: Text(p.name))),
                            ],
                            onChanged: (v) => setState(() => _promoId = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_report != null) ...[
                      ReportSummaryCard(
                        children: [
                          ReportSummaryItem(
                            label: 'Выручка',
                            value:
                                '${_report!.summary['revenue']?.toStringAsFixed(0) ?? '0'} ₽',
                          ),
                          ReportSummaryItem(
                            label: 'Записей',
                            value:
                                '${_report!.summary['appointments_count']?.toInt() ?? 0}',
                          ),
                          ReportSummaryItem(
                            label: 'Средний чек',
                            value: _avgCheck,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ReportTableCard(
                        title: 'Детализация',
                        columns: const [
                          DataColumn(label: Text('Период')),
                          DataColumn(label: Text('Записей')),
                          DataColumn(label: Text('Услуги')),
                          DataColumn(label: Text('Скидки')),
                          DataColumn(label: Text('Выручка')),
                        ],
                        rows: _report!.items
                            .map((e) => DataRow(cells: [
                                  DataCell(Text(e.period)),
                                  DataCell(Text('${e.appointmentsCount}')),
                                  DataCell(Text(
                                      '${e.servicesTotal.toStringAsFixed(0)} ₽')),
                                  DataCell(Text(
                                      '${e.discountsTotal.toStringAsFixed(0)} ₽')),
                                  DataCell(Text(
                                      '${e.revenue.toStringAsFixed(0)} ₽')),
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
