import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app_styles.dart';
import '../../widgets/app_date_picker.dart';
import '../../models/daily_report.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../admin/detailed_analytics_screen.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with SingleTickerProviderStateMixin {
  DailyReport? _report;
  bool _loading = true;
  String? _error;
  DateTime _selectedDate = DateTime.now();
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadReport();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadReport() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final report = await ApiService().getDailyReport(dateStr);

    if (!mounted) return;
    setState(() {
      _report = report;
      _loading = false;
      if (report == null) {
        _error = 'Не удалось загрузить данные';
      }
    });
    _animController.forward(from: 0);
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
      await _loadReport();
    }
  }

  void _previousDay() {
    setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));
    _loadReport();
  }

  void _nextDay() {
    if (_selectedDate.isBefore(DateTime.now())) {
      setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)));
      _loadReport();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.user?.role == UserRole.admin;
    final dark = AppStyles.isDark(context);

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFF),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text('Статистика',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.open_in_new_rounded),
              tooltip: 'Grafana (внешняя)',
              onPressed: () => _openExternalGrafana(),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: AppStyles.primary,
        onRefresh: _loadReport,
        child: CustomScrollView(
          slivers: [
            // Date selector
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _buildDateSelector(context),
              ),
            ),
            // Content
            if (_loading)
              const SliverFillRemaining(child: _SkeletonView())
            else if (_error != null)
              SliverFillRemaining(child: _buildError(context))
            else if (_report != null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildKpiGrid(context, _report!),
                    const SizedBox(height: 20),
                    _buildProgressSection(context, _report!),
                    const SizedBox(height: 20),
                    _buildTopServicesChart(context, _report!),
                    const SizedBox(height: 20),
                    _buildBoxOccupancy(context, _report!),
                    const SizedBox(height: 20),
                    _buildWashersSection(context, _report!),
                    const SizedBox(height: 20),
                    _buildConsumablesAlerts(context, _report!),
                    if (isAdmin) ...[
                      const SizedBox(height: 24),
                      _buildGrafanaButton(context),
                    ],
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector(BuildContext context) {
    final isToday = _isSameDay(_selectedDate, DateTime.now());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppStyles.adaptiveCard(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppStyles.adaptiveBorder(context)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _previousDay,
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    Text(
                      isToday ? 'Сегодня' : _weekdayName(_selectedDate),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppStyles.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('dd MMMM yyyy', 'ru').format(_selectedDate),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppStyles.adaptiveTextPrimary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _isSameDay(_selectedDate, DateTime.now()) ? null : _nextDay,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today_rounded, size: 18),
            onPressed: _pickDate,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildKpiGrid(BuildContext context, DailyReport report) {
    final crossCount = MediaQuery.of(context).size.width > 600 ? 4 : 2;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossCount,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.4,
      children: [
        _KpiCard(
          icon: Icons.payments_rounded,
          label: 'Выручка',
          value: _formatCurrency(report.revenue),
          color: AppStyles.success,
          bgColor: AppStyles.successBg,
          animation: _animController,
          delay: 0,
        ),
        _KpiCard(
          icon: Icons.calendar_month_rounded,
          label: 'Всего записей',
          value: '${report.appointmentsCount}',
          subtitle: '${report.completedCount} выполнено',
          color: AppStyles.primary,
          bgColor: AppStyles.primaryBg,
          animation: _animController,
          delay: 0.1,
        ),
        _KpiCard(
          icon: Icons.receipt_long_rounded,
          label: 'Средний чек',
          value: _formatCurrency(report.averageCheck.toInt()),
          color: AppStyles.warning,
          bgColor: AppStyles.warningBg,
          animation: _animController,
          delay: 0.2,
        ),
        _KpiCard(
          icon: Icons.local_car_wash_rounded,
          label: 'Завершено',
          value: '${report.completedCount}',
          subtitle: report.appointmentsCount > 0
              ? '${(report.completedCount / report.appointmentsCount * 100).toStringAsFixed(0)}%'
              : '0%',
          color: AppStyles.inProgress,
          bgColor: AppStyles.inProgressBg,
          animation: _animController,
          delay: 0.3,
        ),
      ],
    );
  }

  Widget _buildProgressSection(BuildContext context, DailyReport report) {
    final total = report.appointmentsCount;
    final completed = report.completedCount;
    final progress = total > 0 ? completed / total : 0.0;

    return _SectionCard(
      title: 'Выполнение',
      icon: Icons.trending_up_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: AppStyles.adaptiveInnerCard(context),
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 0.8
                    ? AppStyles.success
                    : progress >= 0.5
                        ? AppStyles.warning
                        : AppStyles.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _LegendDot(color: AppStyles.success, label: 'Выполнено: $completed'),
              _LegendDot(color: AppStyles.adaptiveTextMuted(context), label: 'Всего: $total'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopServicesChart(BuildContext context, DailyReport report) {
    if (report.topServices.isEmpty) {
      return const _SectionCard(
        title: 'Топ услуг',
        icon: Icons.star_rounded,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: Text('Нет данных за выбранный день')),
        ),
      );
    }

    final maxCount = report.topServices.map((s) => s.count).reduce((a, b) => a > b ? a : b);
    final barGroups = report.topServices.asMap().entries.map((e) {
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: e.value.count.toDouble(),
            width: 22,
            borderRadius: BorderRadius.circular(6),
            color: AppStyles.primary,
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: maxCount.toDouble(),
              color: AppStyles.adaptiveInnerCard(context),
            ),
          ),
        ],
      );
    }).toList();

    return _SectionCard(
      title: 'Топ услуг',
      icon: Icons.star_rounded,
      child: Column(
        children: [
          const SizedBox(height: 8),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: maxCount * 1.2,
                barGroups: barGroups,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= report.topServices.length) return const SizedBox.shrink();
                        final name = report.topServices[idx].name;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            name.length > 8 ? '${name.substring(0, 8)}...' : name,
                            style: TextStyle(
                              fontSize: 10,
                              color: AppStyles.adaptiveTextSecondary(context),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => AppStyles.adaptiveCard(context),
                    tooltipBorder: BorderSide(color: AppStyles.adaptiveBorder(context)),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final s = report.topServices[groupIndex];
                      return BarTooltipItem(
                        '${s.name}\n${s.count} шт',
                        TextStyle(
                          color: AppStyles.adaptiveTextPrimary(context),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // List below chart
          ...report.topServices.asMap().entries.map((e) {
            final i = e.key;
            final s = e.value;
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _chartColors[i % _chartColors.length].withValues(alpha:0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _chartColors[i % _chartColors.length],
                    ),
                  ),
                ),
              ),
              title: Text(s.name, style: const TextStyle(fontSize: 13)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppStyles.adaptiveInnerCard(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${s.count} шт',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBoxOccupancy(BuildContext context, DailyReport report) {
    if (report.boxOccupancy.isEmpty) {
      return const SizedBox.shrink();
    }

    final entries = report.boxOccupancy.entries.toList();
    final total = entries.fold(0, (sum, e) => sum + e.value);

    return _SectionCard(
      title: 'Загрузка боксов',
      icon: Icons.garage_rounded,
      child: Column(
        children: [
          const SizedBox(height: 8),
          ...entries.map((e) {
            final boxNum = e.key.replaceFirst('box', '');
            final count = e.value;
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
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      Text('$count моек',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppStyles.adaptiveTextSecondary(context),
                            fontWeight: FontWeight.w600,
                          )),
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
                        _boxColor(int.tryParse(boxNum) ?? 1),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildWashersSection(BuildContext context, DailyReport report) {
    if (report.washersOnShift.isEmpty) {
      return const SizedBox.shrink();
    }

    return _SectionCard(
      title: 'Мойщики на смене',
      icon: Icons.people_alt_rounded,
      child: Column(
        children: report.washersOnShift.map((w) {
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: AppStyles.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 18),
            ),
            title: Text(w.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text('${w.start} – ${w.end}',
                style: TextStyle(fontSize: 12, color: AppStyles.adaptiveTextSecondary(context))),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppStyles.successBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppStyles.success.withValues(alpha:0.3)),
              ),
              child: const Text('На смене',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppStyles.success,
                  )),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildConsumablesAlerts(BuildContext context, DailyReport report) {
    if (report.consumablesAlert.isEmpty) {
      return const SizedBox.shrink();
    }

    return _SectionCard(
      title: '⚠️ Критические запасы',
      icon: Icons.warning_amber_rounded,
      accentColor: AppStyles.danger,
      child: Column(
        children: report.consumablesAlert.map((a) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppStyles.dangerBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppStyles.danger.withValues(alpha:0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.inventory_2_outlined, color: AppStyles.danger, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.name,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text('Осталось: ${a.currentStock.toStringAsFixed(1)} (мин. ${a.minStock.toStringAsFixed(1)})',
                          style: const TextStyle(fontSize: 12, color: AppStyles.danger)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppStyles.danger.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${((a.currentStock / a.minStock) * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppStyles.danger,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGrafanaButton(BuildContext context) {
    final dark = AppStyles.isDark(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: dark ? const Color(0xFF334155) : AppStyles.adaptiveBorder(context),
        ),
        boxShadow: [
          if (!dark)
            BoxShadow(
              color: Theme.of(context).colorScheme.shadow.withValues(alpha:0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openGrafana(context),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: AppStyles.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.analytics_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Детальная аналитика',
                        style: TextStyle(
                          color: AppStyles.adaptiveTextPrimary(context),
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Открыть Grafana в приложении',
                        style: TextStyle(
                          color: AppStyles.adaptiveTextSecondary(context),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppStyles.adaptiveTextMuted(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 56, color: AppStyles.danger.withValues(alpha:0.5)),
          const SizedBox(height: 16),
          Text('Ошибка загрузки',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppStyles.adaptiveTextPrimary(context),
              )),
          const SizedBox(height: 8),
          Text(_error!,
              style: TextStyle(color: AppStyles.adaptiveTextSecondary(context))),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadReport,
            icon: const Icon(Icons.refresh),
            label: const Text('Повторить'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppStyles.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  void _openGrafana(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetailedAnalyticsScreen(initialDate: _selectedDate)),
    );
  }

  Future<void> _openExternalGrafana() async {
    const url = 'http://localhost:3000/d/lanwash-api';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _weekdayName(DateTime d) {
    return DateFormat('EEEE', 'ru').format(d);
  }

  String _formatCurrency(int amount) {
    final formatter = NumberFormat('#,###', 'ru');
    return '${formatter.format(amount)} ₽';
  }

  static final _chartColors = [
    AppStyles.primary,
    AppStyles.success,
    AppStyles.warning,
    AppStyles.inProgress,
    AppStyles.danger,
  ];

  static Color _boxColor(int index) {
    final colors = [AppStyles.primary, AppStyles.success, AppStyles.warning, AppStyles.inProgress];
    return colors[(index - 1) % colors.length];
  }
}

// ─── KPI Card ───────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final Color color;
  final Color bgColor;
  final AnimationController animation;
  final double delay;

  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    required this.color,
    required this.bgColor,
    required this.animation,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    final dark = AppStyles.isDark(context);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = (animation.value - delay).clamp(0.0, 1.0) / (1.0 - delay);
        return Transform.translate(
          offset: Offset(0, (1 - t) * 20),
          child: Opacity(opacity: t, child: child),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: dark ? const Color(0xFF334155) : AppStyles.adaptiveBorder(context),
          ),
          boxShadow: [
            if (!dark)
              BoxShadow(
                color: Theme.of(context).colorScheme.shadow.withValues(alpha:0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(value,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppStyles.adaptiveTextPrimary(context),
                      )),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: TextStyle(
                          fontSize: 10,
                          color: AppStyles.adaptiveTextSecondary(context),
                        )),
                  Text(label,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppStyles.adaptiveTextMuted(context),
                        fontWeight: FontWeight.w500,
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Section Card ───────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Color? accentColor;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.accentColor,
  });

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
          color: dark ? const Color(0xFF334155) : AppStyles.adaptiveBorder(context),
        ),
        boxShadow: [
          if (!dark)
            BoxShadow(
              color: Theme.of(context).colorScheme.shadow.withValues(alpha:0.04),
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
                  color: accent.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 18),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppStyles.adaptiveTextPrimary(context),
                  )),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

// ─── Skeleton View ──────────────────────────────────────────────────────────

class _SkeletonView extends StatelessWidget {
  const _SkeletonView();

  @override
  Widget build(BuildContext context) {
    final dark = AppStyles.isDark(context);
    final shimmerColor = dark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    Widget box({double? height, double? width, BorderRadius? radius}) {
      return Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: shimmerColor,
          borderRadius: radius ?? BorderRadius.circular(10),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: Column(
        children: [
          box(height: 60, radius: BorderRadius.circular(14)),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.4,
            children: List.generate(4, (_) => box(radius: BorderRadius.circular(14))),
          ),
          const SizedBox(height: 16),
          box(height: 120, radius: BorderRadius.circular(16)),
          const SizedBox(height: 16),
          box(height: 280, radius: BorderRadius.circular(16)),
        ],
      ),
    );
  }
}

// ─── Legend Dot ─────────────────────────────────────────────────────────────

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(fontSize: 12, color: AppStyles.adaptiveTextSecondary(context))),
      ],
    );
  }
}
