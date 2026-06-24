import 'package:flutter/material.dart';
import 'package:lanwash/app_styles.dart';

class AdminSectionTitle extends StatelessWidget {
  final String title;

  const AdminSectionTitle({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        title.toUpperCase(),
        style: AppStyles.adaptiveLabel(context).copyWith(
          fontSize: 11,
          letterSpacing: 1,
          color: AppStyles.adaptiveTextMuted(context),
        ),
      ),
    );
  }
}
