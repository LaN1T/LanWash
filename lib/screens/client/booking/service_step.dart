import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app_styles.dart';
import '../../../core/service_locator.dart';
import '../../../models/car.dart';
import '../../../models/wash_type.dart';
import '../../../providers/catalog_provider.dart';
import '../../../providers/favorite_provider.dart';
import '../../../services/car_catalog_service.dart';
import '../../../utils/plate_formatter.dart';
import '../../../utils/translit.dart';
import '../../../widgets/car_autocomplete_field.dart';

class ServiceStep extends StatelessWidget {
  final ScrollController? scrollCtrl;
  final GlobalKey<FormState> formKey;
  final List<WashType> washTypes;
  final String washTypeId;
  final Set<String> extras;
  final Set<String> lockedExtras;
  final TextEditingController nameCtrl, brandCtrl, modelCtrl, numCtrl;
  final String? selectedBrand;
  final ValueChanged<String> onBrandSelected;
  final bool isPromo;
  final ValueChanged<WashType> onWashTypeChanged;
  final void Function(String id, bool value) onExtrasChanged;
  final List<Car> cars;
  final int? selectedCarId;
  final ValueChanged<int?> onCarSelected;
  final VoidCallback onAddCar;

  const ServiceStep(
      {super.key,
      this.scrollCtrl,
      required this.formKey,
      required this.washTypes,
      required this.washTypeId,
      required this.extras,
      required this.lockedExtras,
      required this.nameCtrl,
      required this.brandCtrl,
      required this.modelCtrl,
      required this.selectedBrand,
      required this.onBrandSelected,
      required this.numCtrl,
      required this.isPromo,
      required this.onWashTypeChanged,
      required this.onExtrasChanged,
      required this.cars,
      required this.selectedCarId,
      required this.onCarSelected,
      required this.onAddCar});

  @override
  Widget build(BuildContext context) {
    final catalogProvider = context.watch<CatalogProvider>();
    final favoriteProvider = context.watch<FavoriteProvider>();
    final extraServices = catalogProvider.services
        .where((s) => s.category != 'Акции')
        .toList()
      ..sort((a, b) => a.price.compareTo(b.price));

    return SingleChildScrollView(
      controller: scrollCtrl,
      padding: const EdgeInsets.all(20),
      child: Form(
        key: formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Ваши данные',
              style: AppStyles.headingMedium
                  .copyWith(color: AppStyles.adaptiveTextPrimary(context))),
          const SizedBox(height: 14),
          if (cars.isNotEmpty) ...[
            Text('Автомобиль',
                style: TextStyle(
                    color: AppStyles.adaptiveTextSecondary(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Semantics(
              label: 'Автомобиль',
              child: Container(
                decoration: AppStyles.cardDecorationFor(context),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    isExpanded: true,
                    value: selectedCarId,
                    icon: const Icon(Icons.arrow_drop_down),
                    dropdownColor: AppStyles.adaptiveCard(context),
                    style: TextStyle(
                      color: AppStyles.adaptiveTextPrimary(context),
                      fontSize: 14,
                    ),
                    hint: Text('Выберите автомобиль',
                        style: TextStyle(
                            color: AppStyles.adaptiveTextMuted(context))),
                    items: cars.map((car) {
                      return DropdownMenuItem<int?>(
                        value: car.id,
                        child: Text(car.fullDisplay),
                      );
                    }).toList(),
                    onChanged: onCarSelected,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ] else ...[
            Container(
              decoration: AppStyles.cardDecorationFor(context),
              child: ListTile(
                leading: const Icon(Icons.add_circle_outline_rounded,
                    color: AppStyles.primary, size: 22),
                title: Text('Добавить автомобиль',
                    style: TextStyle(
                        color: AppStyles.adaptiveTextPrimary(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                subtitle: Text('Сохраните авто для быстрого выбора',
                    style: TextStyle(
                        color: AppStyles.adaptiveTextSecondary(context),
                        fontSize: 12)),
                trailing: Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: AppStyles.adaptiveTextMuted(context)),
                onTap: onAddCar,
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: nameCtrl,
            style: TextStyle(color: AppStyles.adaptiveTextPrimary(context)),
            decoration: AppStyles.inputDecorationFor(context, 'Ваше имя',
                icon: Icons.person_outline_rounded),
            textCapitalization: TextCapitalization.words,
            onChanged: (v) => applyTranslitRu(nameCtrl, v),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Введите имя' : null,
          ),
          const SizedBox(height: 12),
          CarAutocompleteField(
            label: 'Марка авто',
            icon: Icons.directions_car_outlined,
            controller: brandCtrl,
            optionsBuilder: (q) => sl<CarCatalogService>().searchBrands(q),
            onSelected: (brand) {
              onBrandSelected(brand);
              modelCtrl.clear();
            },
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Введите марку' : null,
          ),
          const SizedBox(height: 12),
          CarAutocompleteField(
            label: 'Модель авто',
            hint: selectedBrand == null ? 'Сначала выберите марку' : null,
            icon: Icons.settings_outlined,
            controller: modelCtrl,
            enabled: selectedBrand != null,
            optionsBuilder: (q) {
              if (selectedBrand == null) return [];
              return sl<CarCatalogService>().searchModels(selectedBrand!, q);
            },
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Введите модель' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: numCtrl,
            style: TextStyle(
                color: AppStyles.adaptiveTextPrimary(context),
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600),
            decoration: _plateDecoration(context),
            inputFormatters: [PlateInputFormatter()],
            validator: validatePlate,
          ),
          const SizedBox(height: 24),
          Row(children: [
            Text('Выберите услугу',
                style: AppStyles.headingMedium
                    .copyWith(color: AppStyles.adaptiveTextPrimary(context))),
            if (isPromo) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: AppStyles.adaptivePrimaryBg(context),
                    borderRadius: BorderRadius.circular(6)),
                child: const Text('Задано акцией',
                    style: TextStyle(
                        color: AppStyles.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ]),
          const SizedBox(height: 12),
          ...washTypes.map((wt) {
            final sel = washTypeId == wt.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: isPromo ? null : () => onWashTypeChanged(wt),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppStyles.adaptiveCard(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: sel
                          ? AppStyles.primary
                          : AppStyles.adaptiveBorder(context),
                      width: sel ? 2 : 1,
                    ),
                    boxShadow: sel
                        ? [
                            BoxShadow(
                                color: AppStyles.primary.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4))
                          ]
                        : [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 2))
                          ],
                  ),
                  child: Row(children: [
                    Expanded(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(wt.name,
                            style: TextStyle(
                              color: AppStyles.adaptiveTextPrimary(context),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            )),
                        const SizedBox(height: 4),
                        Text(wt.description,
                            style: TextStyle(
                              color: AppStyles.adaptiveTextSecondary(context),
                              fontSize: 12,
                            )),
                        const SizedBox(height: 8),
                        Row(children: [
                          Icon(Icons.access_time_rounded,
                              size: 14,
                              color: sel
                                  ? AppStyles.primary
                                  : AppStyles.adaptiveTextSecondary(context)),
                          const SizedBox(width: 4),
                          Text(wt.durationLabel,
                              style: TextStyle(
                                  color: sel
                                      ? AppStyles.primary
                                      : AppStyles.adaptiveTextSecondary(
                                          context),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(width: 16),
                          Icon(Icons.payments_outlined,
                              size: 14,
                              color: sel
                                  ? AppStyles.primary
                                  : AppStyles.adaptiveTextSecondary(context)),
                          const SizedBox(width: 4),
                          Text('${wt.basePrice} ₽',
                              style: TextStyle(
                                  color: sel
                                      ? AppStyles.primary
                                      : AppStyles.adaptiveTextSecondary(
                                          context),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ]),
                      ],
                    )),
                    if (sel)
                      const Icon(Icons.check_circle_rounded,
                          color: AppStyles.primary, size: 24)
                    else
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppStyles.adaptiveBorder(context),
                              width: 2),
                        ),
                      ),
                  ]),
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          Row(children: [
            Text('Дополнительно',
                style: AppStyles.headingMedium
                    .copyWith(color: AppStyles.adaptiveTextPrimary(context))),
            if (isPromo) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: AppStyles.adaptivePrimaryBg(context),
                    borderRadius: BorderRadius.circular(6)),
                child: const Text('Можно добавить',
                    style: TextStyle(
                        color: AppStyles.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ]),
          const SizedBox(height: 12),
          Container(
            decoration: AppStyles.cardDecorationFor(context),
            child: Column(
              children: extraServices.asMap().entries.map((entry) {
                final i = entry.key;
                final svc = entry.value;
                final checked = extras.contains(svc.id);
                final last = i == extraServices.length - 1;
                final isFav = favoriteProvider.isExtraFavorite(svc.id);
                final wt = catalogProvider.washTypeById(washTypeId);
                final isWashIncluded =
                    wt?.includedExtraIds.contains(svc.id) ?? false;
                final isPromoIncluded =
                    lockedExtras.contains(svc.id) && !isWashIncluded;
                final locked = lockedExtras.contains(svc.id);
                return Column(children: [
                  InkWell(
                    onTap:
                        locked ? null : () => onExtrasChanged(svc.id, !checked),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: locked
                                ? AppStyles.primary.withValues(alpha: 0.6)
                                : checked
                                    ? AppStyles.primary
                                    : AppStyles.adaptiveCard(context),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                                color: (locked || checked)
                                    ? AppStyles.primary
                                    : AppStyles.adaptiveBorder(context),
                                width: 1.5),
                          ),
                          child: (locked || checked)
                              ? Icon(
                                  locked
                                      ? Icons.lock_rounded
                                      : Icons.check_rounded,
                                  color: Colors.white,
                                  size: 13)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                      child: Text(svc.name,
                                          style: TextStyle(
                                            color: checked
                                                ? AppStyles.primary
                                                : AppStyles.adaptiveTextPrimary(
                                                    context),
                                            fontSize: 14,
                                            fontWeight: checked
                                                ? FontWeight.w500
                                                : FontWeight.normal,
                                          ))),
                                  const SizedBox(width: 6),
                                  Tooltip(
                                    message: svc.description.isNotEmpty
                                        ? svc.description
                                        : 'Описание услуги пока не добавлено',
                                    triggerMode: TooltipTriggerMode.tap,
                                    child: Icon(Icons.help_outline,
                                        size: 14,
                                        color: AppStyles.adaptiveTextSecondary(
                                            context)),
                                  ),
                                ],
                              ),
                              Text(svc.durationLabel,
                                  style: TextStyle(
                                      color: AppStyles.adaptiveTextSecondary(
                                          context),
                                      fontSize: 11)),
                            ],
                          ),
                        ),
                        if (isWashIncluded)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppStyles.adaptivePrimaryBg(context),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Включено',
                                style: TextStyle(
                                    color: AppStyles.primary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600)),
                          )
                        else if (isPromoIncluded)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppStyles.favorite.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Задано акцией',
                                style: TextStyle(
                                    color: AppStyles.favorite,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600)),
                          )
                        else
                          Text('+${svc.price} ₽',
                              style: TextStyle(
                                color: checked
                                    ? AppStyles.primary
                                    : AppStyles.adaptiveTextSecondary(context),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              )),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () =>
                              favoriteProvider.toggleExtraFavorite(svc.id),
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              isFav
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: 20,
                              color: isFav
                                  ? AppStyles.favorite
                                  : AppStyles.adaptiveTextMuted(context),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                  if (!last)
                    Container(
                        height: 1,
                        color: AppStyles.adaptiveBorder(context),
                        margin: const EdgeInsets.only(left: 48)),
                ]);
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  static InputDecoration _plateDecoration(BuildContext context) {
    final base = AppStyles.inputDecorationFor(context, 'Гос. номер',
        hint: 'А000АА777', icon: Icons.pin_outlined);
    return base.copyWith(
      floatingLabelBehavior: FloatingLabelBehavior.always,
      helperText: 'Формат: А000АА777 · EN→RU авто',
      helperStyle: TextStyle(
          color: AppStyles.adaptiveTextSecondary(context), fontSize: 11),
    );
  }
}
