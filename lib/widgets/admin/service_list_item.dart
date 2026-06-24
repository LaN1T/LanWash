import 'package:flutter/material.dart';
import 'package:lanwash/app_styles.dart';

class ServiceListItem extends StatelessWidget {
  final String name;
  final String? subtitle;
  final String priceText;
  final bool isTotal;

  const ServiceListItem({
    super.key,
    required this.name,
    this.subtitle,
    required this.priceText,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: isTotal ? 15 : 14,
                    fontWeight: isTotal ? FontWeight.w800 : FontWeight.w500,
                    color: AppStyles.adaptiveTextPrimary(context),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppStyles.adaptiveTextSecondary(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            priceText,
            style: isTotal
                ? const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppStyles.primary,
                  )
                : TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppStyles.adaptiveTextPrimary(context),
                  ),
          ),
        ],
      ),
    );
  }
}
