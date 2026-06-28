import 'package:flutter/material.dart';
import '../../app_styles.dart';
import '../shared/statistics_screen.dart';
import 'admin_dashboard_screen.dart';

class AdminStatisticsShellScreen extends StatelessWidget {
  const AdminStatisticsShellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          bottom: TabBar(
            labelColor: AppStyles.primary,
            unselectedLabelColor: AppStyles.adaptiveTextSecondary(context),
            indicatorColor: AppStyles.primary,
            tabs: const [
              Tab(text: 'Дашборд', icon: Icon(Icons.dashboard_outlined)),
              Tab(text: 'Статистика дня', icon: Icon(Icons.bar_chart_outlined)),
            ],
          ),
          title: const Text('Статистика',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        ),
        body: const TabBarView(
          children: [
            AdminDashboardScreen(useScaffold: false),
            StatisticsScreen(useScaffold: false),
          ],
        ),
      ),
    );
  }
}
