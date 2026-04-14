import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_styles.dart';
import '../services/api_service.dart';
import '../models/report_entry.dart';
import '../providers/app_provider.dart';

class ConsumablesReportScreen extends StatefulWidget {
  const ConsumablesReportScreen({super.key});

  @override
  State<ConsumablesReportScreen> createState() => _ConsumablesReportScreenState();
}

class _ConsumablesReportScreenState extends State<ConsumablesReportScreen> {
  ConsumablesUsageReport? _report;
  String _selectedDate = DateFormat('yyyy-MM').format(DateTime.now());
  String _selectedCategory = 'Все'; // Add state for selected category
  List<String> _categories = ['Все']; // Add state for categories list
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchCategoriesAndReport();
  }

  // New method to fetch categories first
  Future<void> _fetchCategoriesAndReport() async {
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      _categories = ['Все', ...await appProvider.getServiceCategories()];
      _categories.sort(); // Ensure categories are sorted
      await _fetchReport();
    } catch (e) {
      setState(() {
        _error = 'Не удалось загрузить категории или отчет: $e';
      });
      _isLoading = false; // Ensure loading is false on error
    }
  }

  Future<void> _fetchReport() async {
    if (_isLoading) return; // Prevent concurrent fetches
    setState(() {
      _isLoading = true;
      _error = null;
      _report = null;
    });
    try {
      final apiService = ApiService();
      final report = await apiService.getConsumablesUsageReport(_selectedDate, category: _selectedCategory);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyles.bgPage,
      appBar: AppBar(
        title: const Text('Расходники', style: TextStyle(color: Colors.white)),
        backgroundColor: AppStyles.primary,
        foregroundColor: Colors.white,
      ),
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
                    // Filter by Category
                    SizedBox(
                      height: 48,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                _fetchReport(); // Fetch report when category changes
                              },
                              selectedColor: AppStyles.primary,
                              labelStyle: TextStyle(
                                color: selected ? Colors.white : AppStyles.textSecondary,
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
                                return Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: ListTile(
                                    title: Text(entry.consumableName,
                                        style: const TextStyle(fontWeight: FontWeight.bold)),
                                    trailing: Text('${entry.totalUsed.toStringAsFixed(2)} ${entry.unit}',
                                        style: const TextStyle(color: AppStyles.primary, fontWeight: FontWeight.bold)),
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
