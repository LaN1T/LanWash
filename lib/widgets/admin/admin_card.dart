import 'package:flutter/material.dart';
import 'package:lanwash/app_styles.dart';

class AdminCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const AdminCard({
    super.key,
    required this.child,
    this.padding = AppStyles.cardPadding,
    this.borderRadius = AppStyles.radius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);

    return Container(
      decoration: BoxDecoration(
        color: AppStyles.adaptiveCard(context),
        borderRadius: radius,
        border: Border.all(color: AppStyles.adaptiveBorder(context)),
        boxShadow: [
          BoxShadow(
            color: AppStyles.primary.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
