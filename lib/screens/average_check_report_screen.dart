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
                                  ? 'Отчет: ${DateFormat('MMMM yyyy', 'ru').format(DateTime.parse('$_selectedDate-01'))}'
                                  : 'Отчет: ${DateFormat('d MMMM yyyy', 'ru').format(DateTime.parse(_selectedDate))}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
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
