import 'package:flutter/material.dart';
import 'package:lanwash/widgets/admin/admin_card.dart';

class ReportSummaryCard extends StatelessWidget {
  final List<Widget> children;

  const ReportSummaryCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: children,
      ),
    );
  }
}
