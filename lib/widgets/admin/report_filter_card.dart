import 'package:flutter/material.dart';
import 'package:lanwash/widgets/admin/admin_card.dart';

class ReportFilterCard extends StatelessWidget {
  final List<Widget> children;
  final VoidCallback onApply;

  const ReportFilterCard({
    super.key,
    required this.children,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: children,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onApply,
              child: const Text('Применить'),
            ),
          ),
        ],
      ),
    );
  }
}
