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

class PopularServicesReportScreen extends StatefulWidget {
  const PopularServicesReportScreen({super.key});

  @override
  State<PopularServicesReportScreen> createState() =>
      _PopularServicesReportScreenState();
}

class _PopularServicesReportScreenState
    extends State<PopularServicesReportScreen> {
  PopularServicesReport? _report;
  String _selectedDate = DateFormat('yyyy-MM').format(DateTime.now());
  String _selectedCategory = 'Все';
  List<String> _categories = ['Все'];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchCategoriesAndReport();
  }

  Future<void> _fetchCategoriesAndReport() async {
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      _categories = ['Все', ...await appProvider.getServiceCategories()];
      _categories.sort();
      await _fetchReport();
    } catch (e) {
      setState(() {
        _error = 'Не удалось загрузить категории или отчет: $e';
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
      final apiService = ApiService();
      final report = await apiService.getPopularAdditionalServices(
          _selectedDate,
          category: _selectedCategory);
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
    final headers = ['Услуга', 'Количество'];
    final data = _report!.data
        .map((e) => [e.serviceName ?? 'Услуга', (e.count ?? 0).toString()])
        .toList();

    final fileName = 'Популярные услуги_${_selectedDate}_$_selectedCategory';

    final pdfBytes = await PdfExportService.createPdfBytes(
        'Отчет: Популярные услуги за $_selectedDate ($_selectedCategory)',
        headers,
        data);

    if (kIsWeb) {
      await FileSaver.instance.saveFile(
        name: '$fileName.pdf',
        bytes: pdfBytes,
        mimeType: MimeType.pdf,
      );
    } else {
      if (!mounted) return;
      await PdfExportService.showExportDialog(
        context,
        title:
            'Отчет: Популярные услуги за $_selectedDate ($_selectedCategory)',
        fileName: fileName,
        pdfBytes: pdfBytes,
      );
    }
  }

  Future<void> _setMonthMode() async {
    final now = DateTime.now();
    setState(() {
      _selectedDate = DateFormat('yyyy-MM').format(now);
    });
    _fetchReport();
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
                                  ? 'Отчет: ${[
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
                                    ][DateTime.parse('$_selectedDate-01').month - 1]} ${DateFormat('yyyy').format(DateTime.parse('$_selectedDate-01'))}'
                                  : 'Отчет: ${DateFormat('d', 'ru').format(DateTime.parse(_selectedDate))} ${[
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
                                    ][DateTime.parse(_selectedDate).month - 1]} ${DateFormat('yyyy').format(DateTime.parse(_selectedDate))}',
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
                            onPressed: _setMonthMode,
                          ),
                          IconButton(
                            icon: const Icon(Icons.date_range,
                                color: AppStyles.primary),
                            onPressed: () => _selectDate(context),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 48,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        scrollDirection: Axis.horizontal,
                        children: _categories.map((cat) {
                          final selected = _selectedCategory == cat;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(cat),
                              selected: selected,
                              onSelected: (_) {
                                setState(() => _selectedCategory = cat);
                                _fetchReport();
                              },
                              selectedColor: AppStyles.primary,
                              labelStyle: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : AppStyles.adaptiveTextSecondary(context),
                                fontSize: 13,
                              ),
                            ),
                          );
                        }).toList(),
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
                                final name = entry.serviceName?.trim() ?? '';
                                final isPromo = Provider.of<AppProvider>(
                                        context,
                                        listen: false)
                                    .promos
                                    .any((p) {
                                  return name.toLowerCase() ==
                                      p.name.trim().toLowerCase();
                                });

                                int count = entry.count ?? 0;
                                String countLabel;
                                if (count % 10 == 1 && count % 100 != 11) {
                                  countLabel = '$count раз';
                                } else if ([2, 3, 4].contains(count % 10) &&
                                    ![12, 13, 14].contains(count % 100)) {
                                  countLabel = '$count раза';
                                } else {
                                  countLabel = '$count раз';
                                }

                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  child: ListTile(
                                    title: Text(
                                      entry.serviceName ?? 'Услуга',
                                      style: TextStyle(
                                        fontWeight: isPromo
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                    trailing: Text(countLabel),
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
