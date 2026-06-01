import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/daily_report.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../admin/grafana_webview_screen.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  DailyReport? _report;
  bool _loading = true;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _loading = true);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final report = await ApiService().getDailyReport(dateStr);
    if (mounted) {
      setState(() {
        _report = report;
        _loading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      await _loadReport();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.user?.role == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Статистика'),
        actions: [
          TextButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            label: Text(
              DateFormat('dd.MM.yyyy').format(_selectedDate),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.analytics),
              tooltip: 'Grafana',
              onPressed: () => _openGrafana(context),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _report == null
              ? const Center(child: Text('Нет данных'))
              : _buildContent(context, _report!, isAdmin),
    );
  }

  Widget _buildContent(BuildContext context, DailyReport report, bool isAdmin) {
    return RefreshIndicator(
      onRefresh: _loadReport,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // KPI Cards
          _buildKpiSection(report),
          const SizedBox(height: 24),

          // Top Services
          _buildSectionTitle('Топ услуг'),
          _buildTopServices(report.topServices),
          const SizedBox(height: 24),

          // Washers on shift
          if (report.washersOnShift.isNotEmpty) ...[
            _buildSectionTitle('Мойщики на смене'),
            _buildWashersShift(report.washersOnShift),
            const SizedBox(height: 24),
          ],

          // Consumables alerts
          if (report.consumablesAlert.isNotEmpty) ...[
            _buildSectionTitle('⚠️ Алерты по расходникам'),
            _buildConsumablesAlert(report.consumablesAlert),
            const SizedBox(height: 24),
          ],

          // Grafana button (admin only)
          if (isAdmin)
            ElevatedButton.icon(
              onPressed: () => _openGrafana(context),
              icon: const Icon(Icons.analytics),
              label: const Text('Открыть Grafana'),
            ),
        ],
      ),
    );
  }

  Widget _buildKpiSection(DailyReport report) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _KpiCard(
          icon: Icons.attach_money,
          label: 'Выручка',
          value: '${report.revenue} ₽',
          color: Colors.green,
        ),
        _KpiCard(
          icon: Icons.calendar_today,
          label: 'Записи',
          value: '${report.appointmentsCount}',
          subtitle: 'Выполнено: ${report.completedCount}',
          color: Colors.blue,
        ),
        _KpiCard(
          icon: Icons.trending_up,
          label: 'Средний чек',
          value: '${report.averageCheck.toStringAsFixed(0)} ₽',
          color: Colors.orange,
        ),
        if (report.boxOccupancy.isNotEmpty)
          _KpiCard(
            icon: Icons.garage,
            label: 'Боксы',
            value: report.boxOccupancy.entries
                .map((e) => '${e.key}: ${e.value}')
                .join(', '),
            color: Colors.purple,
          ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildTopServices(List<TopService> services) {
    if (services.isEmpty) return const Text('Нет данных');
    return Column(
      children: services.asMap().entries.map((entry) {
        final i = entry.key;
        final s = entry.value;
        return ListTile(
          dense: true,
          leading: CircleAvatar(
            radius: 14,
            child: Text('${i + 1}', style: const TextStyle(fontSize: 12)),
          ),
          title: Text(s.name),
          trailing: Text('${s.count} шт'),
        );
      }).toList(),
    );
  }

  Widget _buildWashersShift(List<WasherShift> washers) {
    return Column(
      children: washers.map((w) {
        return ListTile(
          dense: true,
          leading: const Icon(Icons.person_outline),
          title: Text(w.name),
          subtitle: Text('${w.start} – ${w.end}'),
        );
      }).toList(),
    );
  }

  Widget _buildConsumablesAlert(List<ConsumableAlert> alerts) {
    return Column(
      children: alerts.map((a) {
        return ListTile(
          dense: true,
          leading: const Icon(Icons.warning, color: Colors.red),
          title: Text(a.name),
          subtitle: Text('Осталось: ${a.currentStock} ${a.minStock > 0 ? '(мин. ${a.minStock})' : ''}'),
          tileColor: Colors.red.withOpacity(0.05),
        );
      }).toList(),
    );
  }

  void _openGrafana(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GrafanaWebViewScreen()),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final Color color;

  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width > 600 ? 180 : double.infinity,
      constraints: const BoxConstraints(minWidth: 140),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          if (subtitle != null)
            Text(subtitle!, style: TextStyle(color: color.withOpacity(0.7), fontSize: 12)),
        ],
      ),
    );
  }
}
