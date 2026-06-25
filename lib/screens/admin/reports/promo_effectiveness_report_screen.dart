import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:file_saver/file_saver.dart';
import 'package:lanwash/app_styles.dart';
import 'package:lanwash/core/service_locator.dart';
import 'package:lanwash/models/promo.dart';
import 'package:lanwash/models/promo_effectiveness_report.dart';
import 'package:lanwash/services/api_service.dart';
import 'package:lanwash/services/pdf_export_service.dart';
import 'package:lanwash/widgets/admin/report_date_picker_field.dart';
import 'package:lanwash/widgets/admin/report_dropdown_field.dart';
import 'package:lanwash/widgets/admin/report_filter_card.dart';
import 'package:lanwash/widgets/admin/report_summary_card.dart';
import 'package:lanwash/widgets/admin/report_summary_item.dart';
import 'package:lanwash/widgets/admin/report_table_card.dart';

class PromoEffectivenessReportScreen extends StatefulWidget {
  const PromoEffectivenessReportScreen({super.key});

  @override
  State<PromoEffectivenessReportScreen> createState() =>
      _PromoEffectivenessReportScreenState();
}

class _PromoEffectivenessReportScreenState
    extends State<PromoEffectivenessReportScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String? _promoId;
  bool _loading = false;
  PromoEffectivenessReport? _report;
  String? _error;
  List<Promo> _promos = [];

  @override
  void initState() {
    super.initState();
    _loadPromos();
    _load();
  }

  Future<void> _loadPromos() async {
    try {
      final promos = await sl<ApiService>().getPromos();
      if (!mounted) return;
      setState(() => _promos = promos);
    } catch (e) {
      if (kDebugMode) debugPrint('load promos error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось загрузить акции')),
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
      final report = await sl<ApiService>().getPromoEffectivenessReport(
        startDate: _startDate,
        endDate: _endDate,
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
    await PdfExportService.exportPromoEffectivenessReport(_report!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PDF экспортирован')),
    );
  }

  Future<void> _exportExcel() async {
    final params = <String, dynamic>{
      'start_date': DateFormat('yyyy-MM-dd').format(_startDate),
      'end_date': DateFormat('yyyy-MM-dd').format(_endDate),
      if (_promoId != null) 'promo_id': _promoId,
    };
    final bytes = await sl<ApiService>().downloadReportExcel(
      '/reports/promo-effectiveness/',
      params,
    );
    if (bytes == null) return;
    await FileSaver.instance.saveFile(
      name:
          'promo_effectiveness_${DateFormat('yyyy-MM-dd').format(_startDate)}_${DateFormat('yyyy-MM-dd').format(_endDate)}',
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
        title: const Text('Эффективность акций',
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
                            label: 'Акций',
                            value: '${_report!.items.length}',
                          ),
                          ReportSummaryItem(
                            label: 'Всего использований',
                            value:
                                '${_report!.items.fold<int>(0, (sum, e) => sum + e.usesCount)}',
                          ),
                          ReportSummaryItem(
                            label: 'Общая выручка',
                            value:
                                '${_report!.items.fold<double>(0, (sum, e) => sum + e.revenue).toStringAsFixed(0)} ₽',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ReportTableCard(
                        title: 'Детализация',
                        columns: const [
                          DataColumn(label: Text('Акция')),
                          DataColumn(label: Text('Использований')),
                          DataColumn(label: Text('Выручка')),
                          DataColumn(label: Text('Скидка')),
                        ],
                        rows: _report!.items
                            .map((e) => DataRow(cells: [
                                  DataCell(Text(e.promoName)),
                                  DataCell(Text('${e.usesCount}')),
                                  DataCell(Text(
                                      '${e.revenue.toStringAsFixed(0)} ₽')),
                                  DataCell(Text(
                                      '${e.discountTotal.toStringAsFixed(0)} ₽')),
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
