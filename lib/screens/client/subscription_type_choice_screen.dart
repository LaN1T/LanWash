import 'package:flutter/material.dart';
import '../../app_styles.dart';
import 'personal_builder_screen.dart';
import 'ready_plan_catalog_screen.dart';

class SubscriptionTypeChoiceScreen extends StatelessWidget {
  const SubscriptionTypeChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppStyles.adaptiveBorder(context)),
        ),
        title: const Text('Выбор абонемента',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: AppStyles.pagePadding,
        children: [
          _OptionCard(
            icon: Icons.local_offer_outlined,
            title: 'Готовый абонемент',
            subtitle: 'Выберите из каталога выгодных пакетов',
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ReadyPlanCatalogScreen())),
          ),
          const SizedBox(height: 16),
          _OptionCard(
            icon: Icons.build_outlined,
            title: 'Персональный абонемент',
            subtitle: 'Соберите пакет под свои задачи',
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const PersonalBuilderScreen())),
          ),
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppStyles.cardDecorationFor(context),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppStyles.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppStyles.primary, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppStyles.adaptiveTextPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppStyles.adaptiveTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: AppStyles.adaptiveTextMuted(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
