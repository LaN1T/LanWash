import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../app_styles.dart';
import '../../models/appointment.dart';
import '../../models/daily_report.dart';
import '../../services/api_service.dart';
import '../../widgets/app_date_picker.dart';
import 'package:lanwash/core/service_locator.dart';

class DetailedAnalyticsScreen extends StatefulWidget {
  final DateTime initialDate;
  const DetailedAnalyticsScreen({super.key, required this.initialDate});

  @override
  State<DetailedAnalyticsScreen> createState() =>
      _DetailedAnalyticsScreenState();
}

class _DetailedAnalyticsScreenState extends State<DetailedAnalyticsScreen> {
  DailyReport? _report;
  List<Appointment> _appointments = [];
  bool _loading = true;
  String? _error;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final report = await sl<ApiService>().getDailyReport(dateStr);
      final paginated = await sl<ApiService>().getAppointments(date: dateStr);
      if (mounted) {
        setState(() {
          _report = report;
          _appointments = paginated.appointments;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Ошибка загрузки';
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      await _load();
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
        title: const Text('Детальная аналитика',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_rounded),
            onPressed: _pickDate,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppStyles.primary,
        onRefresh: _load,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppStyles.primary))
            : _error != null
                ? Center(
                    child: Text(_error!,
                        style: const TextStyle(color: AppStyles.danger)))
                : _report == null
                    ? const Center(child: Text('Нет данных'))
                    : CustomScrollView(
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                            sliver: SliverList(
                              delegate: SliverChildListDelegate([
                                _DateHeader(date: _selectedDate),
                                const SizedBox(height: 20),
                                _KpiGrid(report: _report!),
                                const SizedBox(height: 24),
                                _HourlyChart(appointments: _appointments),
                                const SizedBox(height: 24),
                                _StatusPieChart(appointments: _appointments),
                                const SizedBox(height: 24),
                                _TopServicesChart(report: _report!),
                                const SizedBox(height: 24),
                                _BoxOccupancy(report: _report!),
                                const SizedBox(height: 24),
                                _WashersSection(report: _report!),
                                const SizedBox(height: 24),
                                _ConsumablesAlerts(report: _report!),
                                const SizedBox(height: 24),
                                _AppointmentsList(appointments: _appointments),
                              ]),
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  final DateTime date;
  const _DateHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    final isToday = DateFormat('yyyy-MM-dd').format(date) ==
        DateFormat('yyyy-MM-dd').format(DateTime.now());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppStyles.adaptiveCard(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppStyles.adaptiveBorder(context)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_month_rounded,
              color: AppStyles.primary, size: 20),
          const SizedBox(width: 10),
          Text(
            isToday
                ? 'Сегодня, ${DateFormat('d MMMM yyyy', 'ru').format(date)}'
                : DateFormat('d MMMM yyyy, EEEE', 'ru').format(date),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppStyles.adaptiveTextPrimary(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  final DailyReport report;
  const _KpiGrid({required this.report});

  @override
  Widget build(BuildContext context) {
    final dark = AppStyles.isDark(context);
    final items = [
      _KpiItem(
        icon: Icons.payments_rounded,
        label: 'Выручка',
        value: _formatCurrency(report.revenue),
        color: AppStyles.success,
        bg: AppStyles.successBg,
      ),
      _KpiItem(
        icon: Icons.calendar_month_rounded,
        label: 'Записей',
        value: '${report.appointmentsCount}',
        sub: '${report.completedCount} выполнено',
        color: AppStyles.primary,
        bg: AppStyles.primaryBg,
      ),
      _KpiItem(
        icon: Icons.receipt_long_rounded,
        label: 'Средний чек',
        value: _formatCurrency(report.averageCheck.toInt()),
        color: AppStyles.warning,
        bg: AppStyles.warningBg,
      ),
      _KpiItem(
        icon: Icons.percent_rounded,
        label: 'Выполнение',
        value: report.appointmentsCount > 0
            ? '${(report.completedCount / report.appointmentsCount * 100).toStringAsFixed(0)}%'
            : '0%',
        color: AppStyles.inProgress,
        bg: AppStyles.inProgressBg,
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: items
          .map((i) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: dark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: dark
                        ? const Color(0xFF334155)
                        : AppStyles.adaptiveBorder(context),
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
                        color: i.bg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(i.icon, color: i.color, size: 22),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(i.value,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppStyles.adaptiveTextPrimary(context),
                            )),
                        if (i.sub != null)
                          Text(i.sub!,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppStyles.adaptiveTextSecondary(context),
                              )),
                        Text(i.label,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppStyles.adaptiveTextMuted(context),
                              fontWeight: FontWeight.w500,
                            )),
                      ],
                    ),
                  ],
                ),
              ))
          .toList(),
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
  _KpiItem(
      {required this.icon,
      required this.label,
      required this.value,
      this.sub,
      required this.color,
      required this.bg});
}

class _HourlyChart extends StatelessWidget {
  final List<Appointment> appointments;
  const _HourlyChart({required this.appointments});

  @override
  Widget build(BuildContext context) {
    final hourly = List<int>.filled(24, 0);
    for (final a in appointments) {
      hourly[a.dateTime.hour]++;
    }
    final maxY = hourly.reduce((a, b) => a > b ? a : b).toDouble();
    final spots = hourly
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
        .toList();

    return _SectionCard(
      title: 'Распределение по часам',
      icon: Icons.access_time_rounded,
      child: SizedBox(
        height: 180,
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
              leftTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 4,
                  getTitlesWidget: (value, meta) {
                    final h = value.toInt();
                    return Text('${h.toString().padLeft(2, '0')}:00',
                        style: TextStyle(
                            fontSize: 10,
                            color: AppStyles.adaptiveTextSecondary(context)));
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
                  show: true,
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

class _StatusPieChart extends StatelessWidget {
  final List<Appointment> appointments;
  const _StatusPieChart({required this.appointments});

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final a in appointments) {
      counts[a.status] = (counts[a.status] ?? 0) + 1;
    }
    if (counts.isEmpty) {
      return const _SectionCard(
        title: 'Статусы записей',
        icon: Icons.pie_chart_outline_rounded,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: Text('Нет данных')),
        ),
      );
    }
    final total = counts.values.fold(0, (a, b) => a + b);
    final colors = {
      'scheduled': AppStyles.primary,
      'in_progress': AppStyles.warning,
      'completed': AppStyles.success,
      'cancelled': AppStyles.danger,
    };
    final sections = counts.entries.map((e) {
      final pct = e.value / total;
      return PieChartSectionData(
        color: colors[e.key] ?? AppStyles.adaptiveTextMuted(context),
        value: e.value.toDouble(),
        title: '${(pct * 100).toStringAsFixed(0)}%',
        radius: 60,
        titleStyle: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();

    return _SectionCard(
      title: 'Статусы записей',
      icon: Icons.pie_chart_outline_rounded,
      child: Row(
        children: [
          SizedBox(
            height: 140,
            width: 140,
            child: PieChart(
                PieChartData(sections: sections, centerSpaceRadius: 0)),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: counts.entries
                  .map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                    color: colors[e.key],
                                    borderRadius: BorderRadius.circular(3))),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(AppStyles.statusLabel(e.key),
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppStyles.adaptiveTextPrimary(
                                            context)))),
                            Text('${e.value}',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppStyles.adaptiveTextSecondary(
                                        context))),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopServicesChart extends StatelessWidget {
  final DailyReport report;
  const _TopServicesChart({required this.report});

  @override
  Widget build(BuildContext context) {
    if (report.topServices.isEmpty) {
      return const _SectionCard(
        title: 'Топ услуг',
        icon: Icons.star_rounded,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: Text('Нет данных')),
        ),
      );
    }
    final maxCount =
        report.topServices.map((s) => s.count).reduce((a, b) => a > b ? a : b);
    return _SectionCard(
      title: 'Топ услуг',
      icon: Icons.star_rounded,
      child: SizedBox(
        height: 160,
        child: BarChart(
          BarChartData(
            maxY: maxCount * 1.2,
            barGroups: report.topServices
                .asMap()
                .entries
                .map((e) => BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value.count.toDouble(),
                          width: 20,
                          borderRadius: BorderRadius.circular(6),
                          color: AppStyles.primary,
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: maxCount.toDouble(),
                            color: AppStyles.adaptiveInnerCard(context),
                          ),
                        ),
                      ],
                    ))
                .toList(),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= report.topServices.length)
                      return const SizedBox.shrink();
                    final name = report.topServices[idx].name;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                          name.length > 8 ? '${name.substring(0, 8)}...' : name,
                          style: TextStyle(
                              fontSize: 10,
                              color: AppStyles.adaptiveTextSecondary(context))),
                    );
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => AppStyles.adaptiveCard(context),
                tooltipBorder:
                    BorderSide(color: AppStyles.adaptiveBorder(context)),
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final s = report.topServices[groupIndex];
                  return BarTooltipItem(
                    '${s.name}\n${s.count} шт',
                    TextStyle(
                        color: AppStyles.adaptiveTextPrimary(context),
                        fontWeight: FontWeight.w600,
                        fontSize: 12),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BoxOccupancy extends StatelessWidget {
  final DailyReport report;
  const _BoxOccupancy({required this.report});

  @override
  Widget build(BuildContext context) {
    if (report.boxOccupancy.isEmpty) return const SizedBox.shrink();
    final entries = report.boxOccupancy.entries.toList();
    final total = entries.fold(0, (sum, e) => sum + e.value);
    final colors = [
      AppStyles.primary,
      AppStyles.success,
      AppStyles.warning,
      AppStyles.inProgress
    ];

    return _SectionCard(
      title: 'Загрузка боксов',
      icon: Icons.garage_rounded,
      child: Column(
        children: entries.asMap().entries.map((entry) {
          final boxNum = entry.value.key.replaceFirst('box', '');
          final count = entry.value.value;
          final pct = total > 0 ? count / total : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Бокс $boxNum',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500)),
                    Text('$count моек',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppStyles.adaptiveTextSecondary(context),
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 8,
                    backgroundColor: AppStyles.adaptiveInnerCard(context),
                    valueColor: AlwaysStoppedAnimation<Color>(
                        colors[entry.key % colors.length]),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _WashersSection extends StatelessWidget {
  final DailyReport report;
  const _WashersSection({required this.report});

  @override
  Widget build(BuildContext context) {
    if (report.washersOnShift.isEmpty) return const SizedBox.shrink();
    return _SectionCard(
      title: 'Мойщики на смене',
      icon: Icons.people_alt_rounded,
      child: Column(
        children: report.washersOnShift
            .map((w) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        gradient: AppStyles.primaryGradient,
                        borderRadius: BorderRadius.circular(10)),
                    child:
                        const Icon(Icons.person, color: Colors.white, size: 18),
                  ),
                  title: Text(w.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text('${w.start} – ${w.end}',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppStyles.adaptiveTextSecondary(context))),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppStyles.successBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: AppStyles.success.withValues(alpha: 0.3)),
                    ),
                    child: const Text('На смене',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppStyles.success)),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _ConsumablesAlerts extends StatelessWidget {
  final DailyReport report;
  const _ConsumablesAlerts({required this.report});

  @override
  Widget build(BuildContext context) {
    if (report.consumablesAlert.isEmpty) return const SizedBox.shrink();
    return _SectionCard(
      title: '⚠️ Критические запасы',
      icon: Icons.warning_amber_rounded,
      accentColor: AppStyles.danger,
      child: Column(
        children: report.consumablesAlert
            .map((a) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppStyles.dangerBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppStyles.danger.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined,
                          color: AppStyles.danger, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text(
                                'Осталось: ${a.currentStock.toStringAsFixed(1)} (мин. ${a.minStock.toStringAsFixed(1)})',
                                style: const TextStyle(
                                    fontSize: 12, color: AppStyles.danger)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: AppStyles.danger.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(
                            '${((a.currentStock / a.minStock) * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppStyles.danger)),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _AppointmentsList extends StatelessWidget {
  final List<Appointment> appointments;
  const _AppointmentsList({required this.appointments});

  @override
  Widget build(BuildContext context) {
    if (appointments.isEmpty) {
      return const _SectionCard(
        title: 'Записи',
        icon: Icons.list_alt_rounded,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: Text('Нет записей за выбранный день')),
        ),
      );
    }
    final sorted = [...appointments]
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return _SectionCard(
      title: 'Записи (${appointments.length})',
      icon: Icons.list_alt_rounded,
      child: Column(
        children: sorted
            .map((a) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppStyles.adaptiveInnerCard(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppStyles.statusColor(a.status)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(AppStyles.statusIcon(a.status),
                            color: AppStyles.statusColor(a.status), size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(DateFormat('HH:mm').format(a.dateTime),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppStyles.adaptiveTextSecondary(
                                        context))),
                            Text(a.carModel,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppStyles.adaptiveTextPrimary(
                                        context))),
                          ],
                        ),
                      ),
                      Text('${a.paidPrice} ₽',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppStyles.primary)),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Color? accentColor;

  const _SectionCard(
      {required this.title,
      required this.icon,
      required this.child,
      this.accentColor});

  @override
  Widget build(BuildContext context) {
    final dark = AppStyles.isDark(context);
    final accent = accentColor ?? AppStyles.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: dark
                ? const Color(0xFF334155)
                : AppStyles.adaptiveBorder(context)),
        boxShadow: [
          if (!dark)
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4)),
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
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: accent, size: 18),
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