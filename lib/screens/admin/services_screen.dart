import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_styles.dart';
import '../../models/service.dart';
import '../../providers/app_provider.dart';
import 'service_detail_screen.dart';
import 'add_edit_service_screen.dart';

class ServicesScreen extends StatefulWidget {
  final bool showHelp;
  const ServicesScreen({super.key, this.showHelp = false});
  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  String _searchText = '';
  String _selectedCategory = 'Все';
  final _search = TextEditingController();

  List<String> _categories(List<Service> services) {
    final cats = services.map((s) => s.category).toSet().toList()..sort();
    return ['Все', ...cats];
  }

  List<Service> _filtered(List<Service> all) => all.where((s) {
        final matchCat =
            _selectedCategory == 'Все' || s.category == _selectedCategory;
        final q = _searchText.toLowerCase();
        final matchSearch = q.isEmpty ||
            s.name.toLowerCase().contains(q) ||
            s.description.toLowerCase().contains(q);
        return matchCat && matchSearch;
      }).toList();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    if (provider.loading)
      return const Center(child: CircularProgressIndicator());

    final cats = _categories(provider.services);
    final list = _filtered(provider.services);

    return Column(children: [
      // Поиск
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: TextField(
          controller: _search,
          onChanged: (v) => setState(() => _searchText = v),
          decoration: AppStyles.inputDecorationFor(context, 'Поиск по услугам',
              icon: Icons.search),
        ),
      ),

      // Фильтр по категориям
      SizedBox(
        height: 48,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          scrollDirection: Axis.horizontal,
          children: cats.map((cat) {
            final selected = _selectedCategory == cat;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(cat),
                selected: selected,
                onSelected: (_) => setState(() => _selectedCategory = cat),
                selectedColor: AppStyles.primary,
                labelStyle: TextStyle(
                  color: selected
                      ? Colors.white
                      : AppStyles.adaptiveTextSecondary(context),
                  fontSize: 13,
                ),
              ),
            );
          }).toList(),
        ),
      ),

      // Список услуг
      Expanded(
        child: list.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.local_car_wash,
                    size: 56,
                    color: AppStyles.adaptiveTextSecondary(context)
                        .withValues(alpha: 0.3)),
                const SizedBox(height: 12),
                Text('Услуги не найдены',
                    style: AppStyles.bodyLarge.copyWith(
                        color: AppStyles.adaptiveTextSecondary(context))),
              ]))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                itemCount: list.length,
                itemBuilder: (ctx, i) => _ServiceCard(
                  service: list[i],
                  showHelp: widget.showHelp,
                  isFavorite: provider.isServiceFavorite(list[i].id),
                  onFavorite: () => provider.toggleServiceFavorite(list[i].id),
                  onTap: () => Navigator.push(
                      ctx,
                      MaterialPageRoute(
                          builder: (_) =>
                              ServiceDetailScreen(service: list[i]))),
                ),
              ),
      ),
    ]);
  }
}

// ─── Карточка услуги ─────────────────────────────────────────────────────────
class _ServiceCard extends StatelessWidget {
  final Service service;
  final bool isFavorite;
  final bool showHelp;
  final VoidCallback onFavorite;
  final VoidCallback onTap;
  const _ServiceCard(
      {required this.service,
      required this.isFavorite,
      required this.showHelp,
      required this.onFavorite,
      required this.onTap});

  Color get _catColor =>
      service.isFromApi ? AppStyles.apiTag : AppStyles.primary;

  @override
  Widget build(BuildContext context) {
    final s = service;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: AppStyles.cardDecorationFor(context),
        child: Padding(
          padding: AppStyles.cardPadding,
          child: Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _catColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  Icon(_categoryIcon(s.category), color: _catColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Expanded(
                        child: Text(s.name,
                            style: AppStyles.headingMedium.copyWith(
                                fontSize: 15,
                                color: AppStyles.adaptiveTextPrimary(context)),
                            overflow: TextOverflow.ellipsis)),
                    if (showHelp) ...[
                      const SizedBox(width: 4),
                      Tooltip(
                        message: s.description,
                        child: Icon(Icons.help_outline,
                            size: 14,
                            color: AppStyles.adaptiveTextSecondary(context)),
                      ),
                    ],
                    IconButton(
                      icon: Icon(isFavorite ? Icons.star : Icons.star_border,
                          color: isFavorite
                              ? AppStyles.favorite
                              : AppStyles.adaptiveTextSecondary(context),
                          size: 20),
                      onPressed: onFavorite,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text(s.description,
                      style: AppStyles.bodySmall.copyWith(
                          color: AppStyles.adaptiveTextSecondary(context)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(children: [
                    _chip(context, Icons.access_time, s.durationLabel),
                    const SizedBox(width: 8),
                    if (s.isFromApi)
                      _chip(context, Icons.local_offer, 'Акция',
                          color: AppStyles.apiTag),
                    const Spacer(),
                    Text('${s.price} ₽',
                        style: AppStyles.price.copyWith(fontSize: 16)),
                  ]),
                ])),
          ]),
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, IconData icon, String text,
      {Color? color}) {
    final effectiveColor = color ?? AppStyles.adaptiveTextSecondary(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: effectiveColor),
        const SizedBox(width: 4),
        Text(text,
            style: TextStyle(
                fontSize: 11,
                color: effectiveColor,
                fontWeight: FontWeight.w500)),
      ]),
    );
  }

  IconData _categoryIcon(String cat) => switch (cat) {
        'Мойка кузова' => Icons.local_car_wash,
        'Обработка стёкол' => Icons.window,
        'Защитные покрытия' => Icons.shield,
        'Уход за салоном' => Icons.airline_seat_recline_normal,
        'Специальные услуги' => Icons.build,
        'Детейлинг' => Icons.auto_awesome,
        'Акции' => Icons.local_offer,
        _ => Icons.car_repair,
      };
}
