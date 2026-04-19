import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../app_styles.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../models/report_entry.dart';
import '../services/pdf_export_service.dart';

class AverageCheckReportScreen extends StatefulWidget {
  const AverageCheckReportScreen({super.key});

  @override
  State<AverageCheckReportScreen> createState() => _AverageCheckReportScreenState();
}

class _AverageCheckReportScreenState extends State<AverageCheckReportScreen> {
  final List<String> _monthNames = [
    'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
    'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'
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
    print("PDF: Кнопка нажата");
    if (_report == null) {
      print("PDF: Отчет пуст");
      return;
    }
    final headers = ['Модель авто', 'Кол-во записей', 'Средний чек (₽)'];
    final data = _report!.data.map((e) => [
      e.carModel,
      e.visitCount.toString(),
      e.avgCheck.toStringAsFixed(0)
    ]).toList();
    
    try {
      print("PDF: Генерация...");
      await PdfExportService.showExportDialog(
        context,
        title: 'Отчет: Средний чек за $_selectedDate',
        fileName: 'Средний_чек_${_selectedDate}',
        headers: headers,
        data: data,
      );      print("PDF: Успешно");
    } catch (e) {
      print("PDF: Ошибка $e");
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_selectedDate.length == 7 ? '$_selectedDate-01' : _selectedDate) ?? DateTime.now(),
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
      backgroundColor: AppStyles.bgPage,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppStyles.primary))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppStyles.danger, fontSize: 16)))
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: Colors.white,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedDate.length == 7
                                  ? 'Отчет: ${_monthNames[DateTime.parse('$_selectedDate-01').month - 1]} ${DateFormat('yyyy').format(DateTime.parse('$_selectedDate-01'))}'
                                  : 'Отчет: ${DateFormat('d', 'ru').format(DateTime.parse(_selectedDate))} ${_monthNames[DateTime.parse(_selectedDate).month - 1]} ${DateFormat('yyyy').format(DateTime.parse(_selectedDate))}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.picture_as_pdf, color: Colors.black),
                            tooltip: 'Скачать отчет',
                            onPressed: downloadPdf,
                          ),
                          IconButton(
                            icon: const Icon(Icons.calendar_month, color: AppStyles.primary),
                            tooltip: 'Весь месяц',
                            onPressed: _setMonthMode,
                          ),
                          IconButton(
                            icon: const Icon(Icons.date_range, color: AppStyles.primary),
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
                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: ListTile(
                                    title: Text(entry.carModel, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text('Чеков: ${entry.visitCount}'),
                                    trailing: Text('${entry.avgCheck.toStringAsFixed(0)} ₽', style: const TextStyle(color: AppStyles.primary, fontWeight: FontWeight.bold)),
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
