import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:file_saver/file_saver.dart';
import 'package:lanwash/app_styles.dart';
import 'package:lanwash/core/service_locator.dart';
import 'package:lanwash/models/report_entry.dart';
import 'package:lanwash/services/api_service.dart';
import 'package:lanwash/services/pdf_export_service.dart';
import 'package:lanwash/widgets/admin/report_filter_card.dart';
import 'package:lanwash/widgets/admin/report_period_picker.dart';
import 'package:lanwash/widgets/admin/report_summary_card.dart';
import 'package:lanwash/widgets/admin/report_summary_item.dart';
import 'package:lanwash/widgets/admin/report_table_card.dart';

class AverageCheckReportScreen extends StatefulWidget {
  const AverageCheckReportScreen({super.key});

  @override
  State<AverageCheckReportScreen> createState() =>
      _AverageCheckReportScreenState();
}

class _AverageCheckReportScreenState extends State<AverageCheckReportScreen> {
  ReportPeriodMode _mode = ReportPeriodMode.month;
  DateTime _selectedMonth = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  MonthlyReport? _report;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchReport();
  }

  String get _periodLabel {
    if (_mode == ReportPeriodMode.month) {
      return DateFormat('MMMM yyyy', 'ru').format(_selectedMonth);
    }
    return DateFormat('dd.MM.yyyy', 'ru').format(_selectedDay);
  }

  String get _periodParam {
    if (_mode == ReportPeriodMode.month) {
      return DateFormat('yyyy-MM').format(_selectedMonth);
    }
    return DateFormat('yyyy-MM-dd').format(_selectedDay);
  }

  Future<void> _fetchReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _report = null;
    });
    try {
      final report = await sl<ApiService>().getAverageCheckReport(_periodParam);
      if (!mounted) return;
      setState(() => _report = report);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Не удалось загрузить отчёт: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _exportPdf() async {
    if (_report == null) return;
    final headers = ['Модель авто', 'Кол-во записей', 'Средний чек (₽)'];
    final data = _report!.data
        .map((e) => [
              e.carModel,
              e.visitCount.toString(),
              e.avgCheck.toStringAsFixed(0),
            ])
        .toList();

    final pdfBytes = await PdfExportService.createPdfBytes(
        'Отчёт: Средний чек за $_periodLabel', headers, data);

    if (kIsWeb) {
      await FileSaver.instance.saveFile(
        name: 'Средний чек_$_periodParam',
        bytes: pdfBytes,
        mimeType: MimeType.pdf,
      );
    } else {
      if (!mounted) return;
      await PdfExportService.showExportDialog(
        context,
        title: 'Отчёт: Средний чек за $_periodLabel',
        fileName: 'Средний чек_$_periodParam',
        pdfBytes: pdfBytes,
      );
    }
  }

  Future<void> _exportExcel() async {
    final bytes = await sl<ApiService>().downloadReportExcel(
      '/reports/monthly-check-vs-price/',
      {'date': _periodParam},
    );
    if (bytes == null) return;
    await FileSaver.instance.saveFile(
      name: 'Средний чек_$_periodParam',
      bytes: bytes,
      mimeType: MimeType.microsoftExcel,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Средний чек по моделям',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppStyles.adaptiveBorder(context)),
        ),
      ),
      body: _isLoading
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
                      onApply: _fetchReport,
                      children: [
                        ReportPeriodPicker(
                          mode: _mode,
                          onModeChanged: (mode) => setState(() => _mode = mode),
                          selectedMonth: _selectedMonth,
                          selectedDay: _selectedDay,
                          onMonthChanged: (m) =>
                              setState(() => _selectedMonth = m),
                          onDayChanged: (d) => setState(() => _selectedDay = d),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_report != null) ...[
                      if (_report!.data.isEmpty)
                        Center(
                          child: Text(
                            'Нет данных за выбранный период.\nУчитываются только завершённые записи.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppStyles.adaptiveTextMuted(context),
                              fontSize: 15,
                            ),
                          ),
                        )
                      else ...[
                        ReportSummaryCard(
                          children: [
                            ReportSummaryItem(
                              label: 'Моделей',
                              value: '${_report!.data.length}',
                            ),
                            ReportSummaryItem(
                              label: 'Всего записей',
                              value:
                                  '${_report!.data.fold<int>(0, (sum, e) => sum + e.visitCount)}',
                            ),
                            ReportSummaryItem(
                              label: 'Средний чек',
                              value: _report!.data.isNotEmpty
                                  ? '${(_report!.data.fold<double>(0, (sum, e) => sum + e.avgCheck) / _report!.data.length).toStringAsFixed(0)} ₽'
                                  : '0 ₽',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ReportTableCard(
                          title: 'Детализация',
                          columns: const [
                            DataColumn(label: Text('Модель авто')),
                            DataColumn(label: Text('Кол-во записей')),
                            DataColumn(label: Text('Средний чек')),
                          ],
                          rows: _report!.data
                              .map((e) => DataRow(cells: [
                                    DataCell(Text(e.carModel)),
                                    DataCell(Text('${e.visitCount}')),
                                    DataCell(Text(
                                        '${e.avgCheck.toStringAsFixed(0)} ₽')),
                                  ]))
                              .toList(),
                          onExportPdf: _exportPdf,
                          onExportExcel: _exportExcel,
                        ),
                      ],
                    ],
                  ],
                ),
    );
  }
}
