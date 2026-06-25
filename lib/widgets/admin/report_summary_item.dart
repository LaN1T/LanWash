import 'package:flutter/material.dart';
import 'package:lanwash/app_styles.dart';

class ReportSummaryItem extends StatelessWidget {
  final String label;
  final String value;

  const ReportSummaryItem({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppStyles.adaptiveTextMuted(context),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppStyles.adaptiveTextPrimary(context),
          ),
        ),
      ],
    );
  }
}
