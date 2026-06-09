import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../app_styles.dart';
import '../../models/admin_dashboard.dart';
import '../../services/api_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  AdminDashboard? _dashboard;
  bool _loading = true;
  String? _error;
  String _period = 'week'; // week | month | quarter

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final now = DateTime.now();
    DateTime from;
    switch (_period) {
      case 'month':
        from = DateTime(now.year, now.month, 1);
        break;
      case 'quarter':
        final quarterStartMonth = ((now.month - 1) ~/ 3) * 3 + 1;
        from = DateTime(now.year, quarterStartMonth, 1);
        break;
      case 'week':
      default:
        from = now.subtract(const Duration(days: 6));
        break;
    }

    final fromStr = DateFormat('yyyy-MM-dd').format(from);
    final toStr = DateFormat('yyyy-MM-dd').format(now);

    final dashboard = await ApiService().getAdminDashboard(fromStr, toStr);

    if (mounted) {
      setState(() {
        _dashboard = dashboard;
        _loading = false;
        if (dashboard == null) {
          _error = 'Не удалось загрузить данные';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppStyles.isDark(context);
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFF),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text('Дашборд',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
      ),
      body: RefreshIndicator(
        color: AppStyles.primary,
        onRefresh: _fetchData,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppStyles.primary))
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!,
                            style: const TextStyle(color: AppStyles.danger)),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _fetchData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Повторить'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppStyles.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  )
                : _dashboard == null
                    ? const Center(child: Text('Нет данных'))
                    : CustomScrollView(
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                            sliver: SliverList(
                              delegate: SliverChildListDelegate([
                                _PeriodSelector(
                                  period: _period,
                                  onChanged: (p) {
                                    setState(() => _period = p);
                                    _fetchData();
                                  },
                                ),
                                const SizedBox(height: 20),
                                _KpiGrid(dashboard: _dashboard!),
                                const SizedBox(height: 24),
                                _RevenueChart(dashboard: _dashboard!),
                                const SizedBox(height: 24),
                                _TopWashers(dashboard: _dashboard!),
                                const SizedBox(height: 24),
                                _TopClients(dashboard: _dashboard!),
                              ]),
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  final String period;
  final ValueChanged<String> onChanged;

  const _PeriodSelector({required this.period, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final options = [
      ('week', 'Неделя'),
      ('month', 'Месяц'),
      ('quarter', 'Квартал'),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppStyles.adaptiveCard(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppStyles.adaptiveBorder(context)),
      ),
      child: Row(
        children: options.map((opt) {
          final sel = period == opt.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(opt.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? AppStyles.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  opt.$2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : AppStyles.adaptiveTextSecondary(context),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  final AdminDashboard dashboard;
  const _KpiGrid({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final items = [
      _KpiItem(
        icon: Icons.payments_rounded,
        label: 'Выручка',
        value: _formatCurrency(dashboard.totalRevenue),
        color: AppStyles.success,
        bg: AppStyles.successBg,
      ),
      _KpiItem(
        icon: Icons.calendar_month_rounded,
        label: 'Записей',
        value: '${dashboard.totalAppointments}',
        sub: '${dashboard.completedAppointments} выполнено',
        color: AppStyles.primary,
        bg: AppStyles.primaryBg,
      ),
      _KpiItem(
        icon: Icons.receipt_long_rounded,
        label: 'Средний чек',
        value: _formatCurrency(dashboard.averageCheck.toInt()),
        color: AppStyles.warning,
        bg: AppStyles.warningBg,
      ),
      _KpiItem(
        icon: Icons.star_rounded,
        label: 'Средний рейтинг',
        value: dashboard.averageRating.toStringAsFixed(1),
        color: AppStyles.inProgress,
        bg: AppStyles.inProgressBg,
      ),
      _KpiItem(
        icon: Icons.person_add_alt_1_rounded,
        label: 'Новые клиенты',
        value: '${dashboard.newClients}',
        color: AppStyles.info,
        bg: const Color(0xFFDBEAFE),
      ),
      _KpiItem(
        icon: Icons.people_alt_rounded,
        label: 'Вернувшиеся',
        value: '${dashboard.returningClients}',
        color: const Color(0xFF7C3AED),
        bg: const Color(0xFFEDE9FE),
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: items.map((i) => _KpiCard(item: i)).toList(),
    );
  }

  String _formatCurrency(int amount) {
    final formatter = NumberFormat('#,###', 'ru');
    return '${formatter.format(amount)} ₽';
  }
}

class _KpiItem {
  final IconData icon;
  final String label;
  final String value;
  final String? sub;
  final Color color;
  final Color bg;
  _KpiItem({
    required this.icon,
    required this.label,
    required this.value,
    this.sub,
    required this.color,
    required this.bg,
  });
}

class _KpiCard extends StatelessWidget {
  final _KpiItem item;
  const _KpiCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final dark = AppStyles.isDark(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: dark ? const Color(0xFF334155) : AppStyles.adaptiveBorder(context),
        ),
        boxShadow: [
          if (!dark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: item.bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, color: item.color, size: 22),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppStyles.adaptiveTextPrimary(context),
                  )),
              if (item.sub != null)
                Text(item.sub!,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppStyles.adaptiveTextSecondary(context),
                    )),
              Text(item.label,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppStyles.adaptiveTextMuted(context),
                    fontWeight: FontWeight.w500,
                  )),
            ],
          ),
        ],
      ),
    );
  }
}

class _RevenueChart extends StatelessWidget {
  final AdminDashboard dashboard;
  const _RevenueChart({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final data = dashboard.dailyBreakdown;
    if (data.isEmpty) {
      return const _SectionCard(
        title: 'Выручка по дням',
        icon: Icons.trending_up_rounded,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: Text('Нет данных')),
        ),
      );
    }

    final spots = data.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.revenue.toDouble());
    }).toList();

    final maxY = data.map((d) => d.revenue).reduce((a, b) => a > b ? a : b).toDouble();

    return _SectionCard(
      title: 'Выручка по дням',
      icon: Icons.trending_up_rounded,
      child: SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: maxY < 1 ? 5 : maxY * 1.2,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: AppStyles.adaptiveBorder(context).withValues(alpha: 0.3),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: data.length > 10 ? 5 : 1,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= data.length) return const SizedBox.shrink();
                    final d = data[idx];
                    return Text(
                      DateFormat('dd.MM').format(DateTime.parse(d.date)),
                      style: TextStyle(
                        fontSize: 10,
                        color: AppStyles.adaptiveTextSecondary(context),
                      ),
                    );
                  },
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.3,
                barWidth: 3,
                color: AppStyles.primary,
                belowBarData: BarAreaData(
                  show: true,
                  color: AppStyles.primary.withValues(alpha: 0.1),
                ),
                dotData: FlDotData(
                  show: data.length <= 14,
                  getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                    radius: 3,
                    color: AppStyles.primary,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopWashers extends StatelessWidget {
  final AdminDashboard dashboard;
  const _TopWashers({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final items = dashboard.topWashers;
    if (items.isEmpty) {
      return const _SectionCard(
        title: 'Топ мойщиков',
        icon: Icons.emoji_events_rounded,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: Text('Нет данных')),
        ),
      );
    }
    return _SectionCard(
      title: 'Топ мойщиков',
      icon: Icons.emoji_events_rounded,
      child: Column(
        children: items.asMap().entries.map((e) {
          final i = e.key;
          final w = e.value;
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _rankColor(i).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text('${i + 1}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _rankColor(i),
                        fontSize: 13)),
              ),
            ),
            title: Text(w.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${w.appointments} записей',
                style: TextStyle(color: AppStyles.adaptiveTextSecondary(context), fontSize: 12)),
            trailing: Text(_formatCurrency(w.revenue),
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppStyles.primary)),
          );
        }).toList(),
      ),
    );
  }

  Color _rankColor(int index) {
    final colors = [const Color(0xFFF59E0B), const Color(0xFF94A3B8), const Color(0xFFCD7F32)];
    return index < 3 ? colors[index] : AppStyles.adaptiveTextMuted(context);
  }

  String _formatCurrency(int amount) {
    final formatter = NumberFormat('#,###', 'ru');
    return '${formatter.format(amount)} ₽';
  }
}

class _TopClients extends StatelessWidget {
  final AdminDashboard dashboard;
  const _TopClients({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final items = dashboard.topClients;
    if (items.isEmpty) {
      return const _SectionCard(
        title: 'Топ клиентов',
        icon: Icons.favorite_rounded,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: Text('Нет данных')),
        ),
      );
    }
    return _SectionCard(
      title: 'Топ клиентов',
      icon: Icons.favorite_rounded,
      child: Column(
        children: items.asMap().entries.map((e) {
          final i = e.key;
          final c = e.value;
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: AppStyles.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 18),
            ),
            title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${c.visits} визитов',
                style: TextStyle(color: AppStyles.adaptiveTextSecondary(context), fontSize: 12)),
            trailing: Text(_formatCurrency(c.totalSpent),
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppStyles.primary)),
          );
        }).toList(),
      ),
    );
  }

  String _formatCurrency(int amount) {
    final formatter = NumberFormat('#,###', 'ru');
    return '${formatter.format(amount)} ₽';
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = AppStyles.isDark(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dark ? const Color(0xFF334155) : AppStyles.adaptiveBorder(context)),
        boxShadow: [
          if (!dark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppStyles.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppStyles.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppStyles.adaptiveTextPrimary(context))),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
