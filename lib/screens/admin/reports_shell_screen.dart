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
      backgroundColor: AppStyles.bgPage,
      appBar: AppBar(
        title: const Text('Отчёты', style: TextStyle(color: Colors.white)),
        backgroundColor: AppStyles.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(
                child:
                    Text('Средний чек', style: TextStyle(color: Colors.white))),
            Tab(
                child: Text('Популярные услуги',
                    style: TextStyle(color: Colors.white))),
            Tab(
                child:
                    Text('Расходники', style: TextStyle(color: Colors.white))),
          ],
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
