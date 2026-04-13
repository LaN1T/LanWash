import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../app_styles.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../models/report_entry.dart';

class AverageCheckReportScreen extends StatefulWidget {
  const AverageCheckReportScreen({super.key});

  @override
  State<AverageCheckReportScreen> createState() => _AverageCheckReportScreenState();
}

class _AverageCheckReportScreenState extends State<AverageCheckReportScreen> {
  MonthlyReport? _report;
  String _selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());
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
    });
    try {
      final apiService = ApiService();
      final report = await apiService.getMonthlyReport(_selectedMonth);
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

  Future<void> _selectMonth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(_selectedMonth + '-01'),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null && DateFormat('yyyy-MM').format(picked) != _selectedMonth) {
      setState(() {
        _selectedMonth = DateFormat('yyyy-MM').format(picked);
      });
      _fetchReport();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyles.bgPage,
      appBar: AppBar(
        title: const Text('Средний чек', style: TextStyle(color: Colors.white)),
        backgroundColor: AppStyles.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            onPressed: () => _selectMonth(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppStyles.primary))
          : _error != null
              ? Center(child: Text(_error!,
                  style: const TextStyle(color: AppStyles.danger, fontSize: 16)))
              : _report == null || _report!.data.isEmpty
                  ? Center(child: Text(
                      'Нет данных за выбранный месяц: $_selectedMonth',
                      style: const TextStyle(color: AppStyles.textSecondary, fontSize: 16),
                    ))
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            () {
                              final date = DateTime.parse(_selectedMonth + '-01');
                              final month = DateFormat('MMMM', 'ru').format(date);
                              final nominative = {
                                'января': 'январь', 'февраля': 'февраль', 'марта': 'март',
                                'апреля': 'апрель', 'мая': 'май', 'июня': 'июнь',
                                'июля': 'июль', 'августа': 'август', 'сентября': 'сентябрь',
                                'октября': 'октябрь', 'ноября': 'ноябрь', 'декабря': 'декабрь',
                              }[month] ?? month;
                              return 'Отчет за месяц: ${nominative[0].toUpperCase() + nominative.substring(1)} ${date.year}';
                            }(),
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppStyles.textPrimary),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _report!.data.length,
                            itemBuilder: (context, index) {
                              final entry = _report!.data[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Модель авто: ${entry.carModel}',
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppStyles.textPrimary),
                                      ),
                                      const SizedBox(height: 8),
                                      Text('Количество посещений: ${entry.visitCount}',
                                          style: const TextStyle(fontSize: 16, color: AppStyles.textSecondary)),
                                      Text('Средний чек: ${entry.avgCheck.toStringAsFixed(2)} ₽',
                                          style: const TextStyle(fontSize: 16, color: AppStyles.textSecondary)),
                                      Text('Средняя цена авто (Auto.ru): ${entry.avgCarPrice} ₽',
                                          style: const TextStyle(fontSize: 16, color: AppStyles.textSecondary)),
                                      Text(
                                        'Соотношение (чек к цене авто): ${entry.ratio.toStringAsFixed(2)} %',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppStyles.primary),
                                      ),
                                    ],
                                  ),
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
