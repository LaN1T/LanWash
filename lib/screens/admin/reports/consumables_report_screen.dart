import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:file_saver/file_saver.dart';
import 'package:lanwash/app_styles.dart';
import 'package:lanwash/core/service_locator.dart';
import 'package:lanwash/models/report_entry.dart';
import 'package:lanwash/providers/catalog_provider.dart';
import 'package:lanwash/services/api_service.dart';
import 'package:lanwash/services/pdf_export_service.dart';
import 'package:lanwash/widgets/admin/report_filter_card.dart';
import 'package:lanwash/widgets/admin/report_period_picker.dart';
import 'package:lanwash/widgets/admin/report_summary_card.dart';
import 'package:lanwash/widgets/admin/report_summary_item.dart';
import 'package:lanwash/widgets/admin/report_table_card.dart';

class ConsumablesReportScreen extends StatefulWidget {
  const ConsumablesReportScreen({super.key});

  @override
  State<ConsumablesReportScreen> createState() =>
      _ConsumablesReportScreenState();
}

class _ConsumablesReportScreenState extends State<ConsumablesReportScreen> {
  ReportPeriodMode _mode = ReportPeriodMode.month;
  DateTime _selectedMonth = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  String _selectedCategory = 'Все';
  List<String> _categories = ['Все'];
  ConsumablesUsageReport? _report;
  bool _isLoading = false;
  String? _error;

  List<ConsumableUsageEntry> get _reportData =>
      _report?.data.where((e) => e.totalUsed > 0).toList() ?? [];

  @override
  void initState() {
    super.initState();
    _fetchCategoriesAndReport();
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

  Future<void> _fetchCategoriesAndReport() async {
    try {
      final catalogProvider =
          Provider.of<CatalogProvider>(context, listen: false);
      final categories = [
        'Все',
        ...await catalogProvider.getServiceCategories()
      ]..sort();
      if (!mounted) return;
      setState(() => _categories = categories);
      await _fetchReport();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить категории или отчёт: $e';
      });
      _isLoading = false;
    }
  }

  Future<void> _fetchReport() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _report = null;
    });
    try {
      final report = await sl<ApiService>().getConsumablesUsageReport(
        _periodParam,
        category: _selectedCategory,
      );
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
    final headers = ['Расходник', 'Ед.', 'Всего'];
    final data = _report!.data
        .where((e) => e.totalUsed > 0)
        .map((e) => [e.consumableName, e.unit, e.totalUsed.toString()])
        .toList();

    final fileName = 'Расходники_${_periodParam}_$_selectedCategory';
    final pdfBytes = await PdfExportService.createPdfBytes(
      'Отчёт: Расходники за $_periodLabel ($_selectedCategory)',
      headers,
      data,
    );

    if (kIsWeb) {
      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: pdfBytes,
        mimeType: MimeType.pdf,
      );
    } else {
      if (!mounted) return;
      await PdfExportService.showExportDialog(
        context,
        title: 'Отчёт: Расходники за $_periodLabel ($_selectedCategory)',
        fileName: fileName,
        pdfBytes: pdfBytes,
      );
    }
  }

  Future<void> _exportExcel() async {
    final params = <String, dynamic>{'date': _periodParam};
    if (_selectedCategory != 'Все') params['category'] = _selectedCategory;
    final bytes = await sl<ApiService>().downloadReportExcel(
      '/reports/consumables-usage/',
      params,
    );
    if (bytes == null) return;
    final fileName = 'Расходники_${_periodParam}_$_selectedCategory';
    await FileSaver.instance.saveFile(
      name: fileName,
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
        title: const Text('Расходники',
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
                        SizedBox(
                          width: double.infinity,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _categories.map((cat) {
                              final selected = _selectedCategory == cat;
                              return ChoiceChip(
                                label: Text(cat),
                                selected: selected,
                                onSelected: (_) =>
                                    setState(() => _selectedCategory = cat),
                                selectedColor: AppStyles.primary,
                                labelStyle: TextStyle(
                                  color: selected
                                      ? Colors.white
                                      : AppStyles.adaptiveTextSecondary(
                                          context),
                                  fontSize: 13,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_report != null) ...[
                      if (_reportData.isEmpty)
                        Center(
                          child: Text(
                            'Нет расходников и списаний за период.\nУчитываются только завершённые записи.',
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
                              label: 'Расходников',
                              value: '${_reportData.length}',
                            ),
                            ReportSummaryItem(
                              label: 'Всего использовано',
                              value: _reportData
                                  .fold<double>(
                                      0, (sum, e) => sum + e.totalUsed)
                                  .toStringAsFixed(0),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ReportTableCard(
                          title: 'Детализация',
                          columns: const [
                            DataColumn(label: Text('Расходник')),
                            DataColumn(label: Text('Ед.')),
                            DataColumn(label: Text('Всего')),
                          ],
                          rows: _reportData
                              .map((e) => DataRow(cells: [
                                    DataCell(Text(e.consumableName)),
                                    DataCell(Text(e.unit)),
                                    DataCell(Text(e.totalUsed.toString())),
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
