import 'package:flutter/material.dart';
import 'package:lanwash/app_styles.dart';
import 'package:lanwash/providers/consumable_provider.dart';
import 'package:lanwash/widgets/admin/admin_card.dart';
import 'package:provider/provider.dart';
import 'wash_type_settings_screen.dart';
import 'subscription_plan_settings_screen.dart';
import 'consumables_stock_screen.dart';
import 'consumable_links_screen.dart';
import 'inventory_forecast_screen.dart';

class AdminSettingsShellScreen extends StatefulWidget {
  const AdminSettingsShellScreen({super.key});

  @override
  State<AdminSettingsShellScreen> createState() =>
      _AdminSettingsShellScreenState();
}

class _AdminSettingsShellScreenState extends State<AdminSettingsShellScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConsumableProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final lowStockCount = context.watch<ConsumableProvider>().lowStockCount;
    final items = [
      _SettingsItem(
        title: 'Типы мойки',
        subtitle: 'Цены, длительность, включённые услуги',
        group: 'МОЙКА',
        icon: Icons.local_car_wash_outlined,
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const WashTypeSettingsScreen())),
      ),
      _SettingsItem(
        title: 'Готовые абонементы',
        subtitle: 'Пакеты моек и безлимитные абонементы',
        group: 'МОЙКА',
        icon: Icons.card_membership_outlined,
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const SubscriptionPlanSettingsScreen())),
      ),
      _SettingsItem(
        title: 'Управление запасами',
        subtitle: 'Остатки расходных материалов',
        group: 'РАСХОДНИКИ',
        icon: Icons.inventory_2_outlined,
        badgeCount: lowStockCount,
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ConsumablesStockScreen())),
      ),
      _SettingsItem(
        title: 'Нормы расхода',
        subtitle: 'Привязка расходников к услугам',
        group: 'РАСХОДНИКИ',
        icon: Icons.link_outlined,
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ConsumableLinksScreen())),
      ),
      _SettingsItem(
        title: 'Прогноз расходников',
        subtitle: 'Когда заканчиваются запасы',
        group: 'РАСХОДНИКИ',
        icon: Icons.trending_up_outlined,
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const InventoryForecastScreen())),
      ),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Настройки',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppStyles.adaptiveBorder(context)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items.asMap().entries.expand((entry) {
            final index = entry.key;
            final item = entry.value;
            final showHeader =
                index == 0 || items[index - 1].group != item.group;
            return [
              if (showHeader)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10, left: 4, top: 8),
                  child: Text(
                    item.group,
                    style: TextStyle(
                      color: AppStyles.adaptiveTextMuted(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              AdminCard(
                padding: const EdgeInsets.all(0),
                child: InkWell(
                  onTap: item.onTap,
                  borderRadius: BorderRadius.circular(AppStyles.radius),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppStyles.adaptivePrimaryBg(context),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(item.icon,
                              color: AppStyles.primary, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppStyles.adaptiveTextPrimary(
                                            context),
                                      ),
                                    ),
                                  ),
                                  if (item.badgeCount > 0) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppStyles.danger,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${item.badgeCount}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.subtitle,
                                style: TextStyle(
                                  fontSize: 13,
                                  color:
                                      AppStyles.adaptiveTextSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right,
                            color: AppStyles.adaptiveTextSecondary(context)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ];
          }).toList(),
        ),
      ),
    );
  }
}

class _SettingsItem {
  final String title;
  final String subtitle;
  final String group;
  final IconData icon;
  final VoidCallback onTap;
  final int badgeCount;

  _SettingsItem({
    required this.title,
    required this.subtitle,
    required this.group,
    required this.icon,
    required this.onTap,
    this.badgeCount = 0,
  });
}
