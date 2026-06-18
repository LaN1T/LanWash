import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../app_styles.dart';
import '../../widgets/app_date_picker.dart';
import '../../models/appointment.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/catalog_provider.dart';
import 'appointment_detail_screen.dart';
import '../../models/service.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});
  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  Set<String> _selectedFilters = {'all'};
  final _search = TextEditingController();
  String _searchText = '';
  Timer? _searchDebounce;

  static const _filters = [
    ('all', 'Все'),
    ('scheduled', 'Запланированы'),
    ('in_progress', 'В процессе'),
    ('completed', 'Завершены'),
  ];

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onFilterSelected(String filterKey) {
    setState(() {
      if (filterKey == 'all') {
        _selectedFilters = {'all'};
      } else {
        if (_selectedFilters.contains(filterKey)) {
          _selectedFilters.remove(filterKey);
          if (_selectedFilters.isEmpty) {
            _selectedFilters.add('all');
          }
        } else {
          _selectedFilters.remove('all');
          _selectedFilters.add(filterKey);

          final specificFilters = {'scheduled', 'in_progress', 'completed'};
          final intersection = _selectedFilters.intersection(specificFilters);
          if (intersection.length == 3) {
            _selectedFilters = {'all'};
          }
        }
      }
    });
  }

  List<Appointment> _filtered(List<Appointment> all) {
    final filtered = all.where((a) {
      final matchStatus = _selectedFilters.contains('all') ||
          _selectedFilters.contains(a.status);
      final q = _searchText.toLowerCase();
      final matchSearch = q.isEmpty ||
          a.clientName.toLowerCase().contains(q) ||
          a.carModel.toLowerCase().contains(q) ||
          a.carNumber.toLowerCase().contains(q);
      return matchStatus && matchSearch;
    }).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final appointmentProvider = context.watch<AppointmentProvider>();
    final catalogProvider = context.watch<CatalogProvider>();
    if (appointmentProvider.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final list = _filtered(appointmentProvider.appointments);

    return Column(children: [
      _buildSearchBar(),
      _buildFilters(),
      Expanded(
        child: RefreshIndicator(
          color: AppStyles.primary,
          onRefresh: () => appointmentProvider
              .reloadAppointments(context.read<AuthProvider>()),
          child: list.isEmpty
              ? _emptyState(context)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  itemCount: list.length,
                  itemBuilder: (ctx, i) => _AppointmentCard(
                    appointment: list[i],
                    services: catalogProvider.services,
                    onFavorite: () => appointmentProvider
                        .toggleAppointmentFavorite(list[i].id),
                    onTap: () => Navigator.push(
                        ctx,
                        MaterialPageRoute(
                            builder: (_) =>
                                AppointmentDetailScreen(appointment: list[i]))),
                  ),
                ),
        ),
      ),
      _buildPagination(appointmentProvider),
    ]);
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final parts = dateStr.split('-');
      if (parts.length != 3) return dateStr;
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);
      final date = DateTime(year, month, day);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final tomorrow = today.add(const Duration(days: 1));

      final compareDate = DateTime(date.year, date.month, date.day);
      if (compareDate == today) {
        return 'Сегодня, ${DateFormat('d MMMM', 'ru').format(date)}';
      } else if (compareDate == yesterday) {
        return 'Вчера, ${DateFormat('d MMMM', 'ru').format(date)}';
      } else if (compareDate == tomorrow) {
        return 'Завтра, ${DateFormat('d MMMM', 'ru').format(date)}';
      } else {
        final formatted = DateFormat('EEEE, d MMMM', 'ru').format(date);
        return formatted[0].toUpperCase() + formatted.substring(1);
      }
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildPagination(AppointmentProvider provider) {
    if (provider.totalPages <= 1) return const SizedBox.shrink();

    final auth = context.read<AuthProvider>();
    final currentPage = provider.currentPage;
    final hasNext = currentPage < provider.totalPages;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: AppStyles.adaptiveCard(context),
        border:
            Border(top: BorderSide(color: AppStyles.adaptiveBorder(context))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: currentPage > 1
                ? () => provider.setPage(currentPage - 1, auth)
                : null,
            icon: const Icon(Icons.chevron_left, size: 28),
            color: AppStyles.primary,
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: () async {
              final initialDateStr = provider.currentDate;
              DateTime initialDate = DateTime.now();
              if (initialDateStr.isNotEmpty) {
                final parts = initialDateStr.split('-');
                if (parts.length == 3) {
                  initialDate = DateTime(int.parse(parts[0]),
                      int.parse(parts[1]), int.parse(parts[2]));
                }
              }

              final picked = await showAppDatePicker(
                context: context,
                initialDate: initialDate,
                firstDate: DateTime(2025),
                lastDate: DateTime(2030),
                locale: const Locale('ru', 'RU'),
                selectableDayPredicate: (day) {
                  final formattedDay = DateFormat('yyyy-MM-dd').format(day);
                  return provider.uniqueDates.contains(formattedDay);
                },
              );

              if (picked != null) {
                final formattedPicked = DateFormat('yyyy-MM-dd').format(picked);
                provider.setDate(formattedPicked, auth);
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 16, color: AppStyles.primary),
                  const SizedBox(width: 8),
                  Text(
                    _formatDate(provider.currentDate),
                    style: AppStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppStyles.adaptiveTextPrimary(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed:
                hasNext ? () => provider.setPage(currentPage + 1, auth) : null,
            icon: const Icon(Icons.chevron_right, size: 28),
            color: AppStyles.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: TextField(
          controller: _search,
          onChanged: (v) {
            _searchDebounce?.cancel();
            _searchDebounce = Timer(const Duration(milliseconds: 300), () {
              setState(() => _searchText = v);
            });
          },
          decoration: AppStyles.inputDecorationFor(
              context, 'Поиск по клиенту, авто, номеру',
              icon: Icons.search),
          style: AppStyles.bodyLarge,
        ),
      );

  Widget _buildFilters() => SizedBox(
        height: 48,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          scrollDirection: Axis.horizontal,
          itemCount: _filters.length,
          itemBuilder: (context, index) {
            final f = _filters[index];
            final selected = _selectedFilters.contains(f.$1);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(f.$2),
                selected: selected,
                onSelected: (_) => _onFilterSelected(f.$1),
                selectedColor: AppStyles.primary,
                labelStyle: TextStyle(
                  color: selected
                      ? Colors.white
                      : AppStyles.adaptiveTextSecondary(context),
                  fontSize: 13,
                ),
              ),
            );
          },
        ),
      );

  Widget _emptyState(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.calendar_today_outlined,
              size: 64,
              color: AppStyles.adaptiveTextSecondary(context)
                  .withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text('Нет записей',
              style: AppStyles.headingMedium
                  .copyWith(color: AppStyles.adaptiveTextSecondary(context))),
          const SizedBox(height: 6),
          Text('Нажмите + чтобы добавить запись',
              style: AppStyles.bodyMedium
                  .copyWith(color: AppStyles.adaptiveTextSecondary(context))),
        ]),
      );
}

// ─── Карточка записи ─────────────────────────────────────────────────────────
class _AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final List<dynamic> services;
  final VoidCallback onFavorite;
  final VoidCallback onTap;

  const _AppointmentCard(
      {required this.appointment,
      required this.services,
      required this.onFavorite,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final dateStr = DateFormat('d MMM, HH:mm', 'ru').format(a.dateTime);
    final statusColor = AppStyles.statusColor(a.status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: AppStyles.cardDecorationFor(context),
        child: Padding(
          padding: AppStyles.cardPadding,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              // Статус-иконка
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(AppStyles.statusIcon(a.status),
                    color: statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(a.clientName,
                        style: AppStyles.headingMedium.copyWith(
                            color: AppStyles.adaptiveTextPrimary(context)),
                        overflow: TextOverflow.ellipsis),
                    Text(a.carModel,
                        style: AppStyles.bodyMedium.copyWith(
                            color: AppStyles.adaptiveTextSecondary(context))),
                  ])),
              IconButton(
                icon: Icon(a.isFavorite ? Icons.star : Icons.star_border,
                    color: a.isFavorite
                        ? AppStyles.favorite
                        : AppStyles.adaptiveTextSecondary(context)),
                onPressed: onFavorite,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ]),
            const SizedBox(height: 10),
            Divider(height: 1, color: AppStyles.adaptiveBorder(context)),
            const SizedBox(height: 10),
            Row(children: [
              _info(context, Icons.calendar_today, dateStr),
              const SizedBox(width: 16),
              _info(context, Icons.pin, a.carNumber),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(AppStyles.statusLabel(a.status),
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              _info(context, Icons.local_car_wash,
                  context.watch<CatalogProvider>().washTypeName(a.washTypeId)),
              const Spacer(),
              if (a.priceChanged)
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${a.paidPrice} ₽',
                      style: AppStyles.price.copyWith(fontSize: 15)),
                  Text('${a.originalPrice} ₽',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppStyles.adaptiveTextSecondary(context),
                        decoration: TextDecoration.lineThrough,
                        decorationColor:
                            AppStyles.adaptiveTextSecondary(context),
                      )),
                ])
              else
                Text(
                    '${a.calculateTotalPrice(services.cast<Service>(), context.watch<CatalogProvider>().washTypeById(a.washTypeId))} ₽',
                    style: AppStyles.price.copyWith(fontSize: 15)),
            ]),
            if (a.additionalServices.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: a.additionalServices.map((id) {
                    final service = services.firstWhere((s) => s.id == id,
                        orElse: () => Service(
                            id: id,
                            name: 'Услуга недоступна',
                            description: '',
                            price: 0,
                            durationMinutes: 0,
                            category: ''));
                    final name = service.name;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppStyles.primaryLight.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(name,
                          style: AppStyles.bodySmall
                              .copyWith(color: AppStyles.primaryDark)),
                    );
                  }).toList()),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _info(BuildContext context, IconData icon, String text) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: AppStyles.adaptiveTextSecondary(context)),
        const SizedBox(width: 4),
        Text(text,
            style: AppStyles.bodySmall
                .copyWith(color: AppStyles.adaptiveTextSecondary(context))),
      ]);
}
