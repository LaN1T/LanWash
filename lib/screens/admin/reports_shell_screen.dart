import 'package:flutter/material.dart';
import '../../app_styles.dart';
import 'average_check_report_screen.dart';
import 'popular_services_report_screen.dart';
import 'consumables_report_screen.dart';

class ReportsShellScreen extends StatefulWidget {
  const ReportsShellScreen({super.key});

  @override
  State<ReportsShellScreen> createState() => _ReportsShellScreenState();
}

class _ReportsShellScreenState extends State<ReportsShellScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Отчёты',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight + 1),
          child: Column(
            children: [
              Container(height: 1, color: AppStyles.adaptiveBorder(context)),
              TabBar(
                controller: _tabController,
                indicatorColor: AppStyles.primary,
                labelColor: AppStyles.primary,
                unselectedLabelColor: AppStyles.adaptiveTextSecondary(context),
                tabs: const [
                  Tab(child: Text('Средний чек')),
                  Tab(child: Text('Популярные услуги')),
                  Tab(child: Text('Расходники')),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          AverageCheckReportScreen(),
          PopularServicesReportScreen(),
          ConsumablesReportScreen(),
        ],
      ),
    );
  }
}
