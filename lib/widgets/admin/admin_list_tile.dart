import 'package:flutter/material.dart';
import 'package:lanwash/app_styles.dart';

class AdminListTile extends StatelessWidget {
  final IconData? icon;
  final Widget? iconWidget;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const AdminListTile({
    super.key,
    this.icon,
    this.iconWidget,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  }) : assert(icon == null || iconWidget == null);

  @override
  Widget build(BuildContext context) {
    final iconContent = iconWidget ??
        (icon != null
            ? Icon(
                icon,
                color: AppStyles.primary,
                size: 20,
              )
            : const SizedBox.shrink());

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppStyles.radius),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppStyles.adaptivePrimaryBg(context),
                borderRadius: BorderRadius.circular(AppStyles.radiusSm),
              ),
              alignment: Alignment.center,
              child: iconContent,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
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
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
