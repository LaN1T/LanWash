import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:file_saver/file_saver.dart';
import 'package:printing/printing.dart';

import '../../app_styles.dart';
import '../../providers/app_provider.dart';
import '../../services/api_service.dart';
import '../../models/report_entry.dart';
import '../../services/pdf_export_service.dart';

class AverageCheckReportScreen extends StatefulWidget {
  const AverageCheckReportScreen({super.key});

  @override
  State<AverageCheckReportScreen> createState() =>
      _AverageCheckReportScreenState();
}

class _AverageCheckReportScreenState extends State<AverageCheckReportScreen> {
  final List<String> _monthNames = [
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
    'Август',
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь'
  ];
  MonthlyReport? _report;
  String _selectedDate = DateFormat('yyyy-MM').format(DateTime.now());
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchReport();
  }

  Future<void> _fetchReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _report = null;
    });
    try {
      final apiService = ApiService();
      final report = await apiService.getAverageCheckReport(_selectedDate);
      setState(() {
        _report = report;
      });
    } catch (e) {
      setState(() {
        _error = 'Не удалось загрузить отчет: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> downloadPdf() async {
    if (_report == null) return;
    final headers = ['Модель авто', 'Кол-во записей', 'Средний чек (₽)'];
    final data = _report!.data
        .map((e) => [
              e.carModel,
              e.visitCount.toString(),
              e.avgCheck.toStringAsFixed(0)
            ])
        .toList();

    final pdfBytes = await PdfExportService.createPdfBytes(
        'Отчет: Средний чек за $_selectedDate', headers, data);

    if (kIsWeb) {
      await FileSaver.instance.saveFile(
        name: 'Средний чек_${_selectedDate}.pdf',
        bytes: pdfBytes,
        mimeType: MimeType.pdf,
      );
    } else {
      if (!mounted) return;
      await PdfExportService.showExportDialog(
        context,
        title: 'Отчет: Средний чек за $_selectedDate',
        fileName: 'Средний чек_${_selectedDate}',
        pdfBytes: pdfBytes,
      );
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_selectedDate.length == 7
              ? '$_selectedDate-01'
              : _selectedDate) ??
          DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.day,
      locale: const Locale('ru', 'RU'),
    );
    if (picked != null) {
      final newDate = DateFormat('yyyy-MM-dd').format(picked);
      if (newDate != _selectedDate) {
        setState(() {
          _selectedDate = newDate;
        });
        _fetchReport();
      }
    }
  }

  Future<void> _setMonthMode() async {
    setState(() {
      _selectedDate = DateFormat('yyyy-MM').format(DateTime.now());
    });
    _fetchReport();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppStyles.primary))
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style: TextStyle(
                          color: AppStyles.danger, fontSize: 16)))
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      color: AppStyles.adaptiveCard(context),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedDate.length == 7
                                  ? 'Отчет: ${_monthNames[DateTime.parse('$_selectedDate-01').month - 1]} ${DateFormat('yyyy').format(DateTime.parse('$_selectedDate-01'))}'
                                  : 'Отчет: ${DateFormat('d', 'ru').format(DateTime.parse(_selectedDate))} ${_monthNames[DateTime.parse(_selectedDate).month - 1]} ${DateFormat('yyyy').format(DateTime.parse(_selectedDate))}',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.picture_as_pdf,
                                color: AppStyles.adaptiveTextPrimary(context)),
                            tooltip: 'Скачать отчет',
                            onPressed: downloadPdf,
                          ),
                          IconButton(
                            icon: const Icon(Icons.calendar_month,
                                color: AppStyles.primary),
                            tooltip: 'Весь месяц',
                            onPressed: _setMonthMode,
                          ),
                          IconButton(
                            icon: const Icon(Icons.date_range,
                                color: AppStyles.primary),
                            tooltip: 'Выбрать день',
                            onPressed: () => _selectDate(context),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: (_report == null || _report!.data.isEmpty)
                          ? const Center(child: Text('Нет данных'))
                          : ListView.builder(
                              itemCount: _report!.data.length,
                              itemBuilder: (context, index) {
                                final entry = _report!.data[index];
                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  child: ListTile(
                                    title: Text(entry.carModel,
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    subtitle:
                                        Text('Чеков: ${entry.visitCount}'),
                                    trailing: Text(
                                        '${entry.avgCheck.toStringAsFixed(0)} ₽',
                                        style: TextStyle(
                                            color: AppStyles.primary,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}
