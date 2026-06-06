import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_styles.dart';
import '../../providers/auth_provider.dart';
import '../../providers/catalog_provider.dart';
import 'booking_wizard_screen.dart';
import 'promos_screen.dart';

class ClientHomeScreen extends StatelessWidget {
  const ClientHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final catalogProvider = context.watch<CatalogProvider>();
    final auth = context.watch<AuthProvider>();
    final promos = catalogProvider.promos;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Приветствие ──────────────────────────────────────────────────
        Builder(builder: (context) {
          final hour = DateTime.now().hour;
          String greeting;
          if (hour < 6) {
            greeting = 'Доброй ночи, ';
          } else if (hour < 12) {
            greeting = 'Доброе утро, ';
          } else if (hour < 18) {
            greeting = 'Добрый день, ';
          } else {
            greeting = 'Добрый вечер, ';
          }
          return RichText(
              text: TextSpan(children: [
            TextSpan(
                text: greeting,
                style: TextStyle(
                    color: AppStyles.adaptiveTextSecondary(context),
                    fontSize: 15)),
            TextSpan(
                text: auth.username,
                style: TextStyle(
                    color: AppStyles.adaptiveTextPrimary(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
          ]));
        }),
        const SizedBox(height: 20),

        // ── Большая кнопка записи ────────────────────────────────────────
        GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const BookingWizardScreen())),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
            decoration: BoxDecoration(
              gradient: AppStyles.primaryGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppStyles.primary.withValues(alpha: 0.35),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.local_car_wash,
                    color: Colors.white, size: 36),
              ),
              const SizedBox(height: 14),
              const Text('Записаться на мойку',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Выберите дату, время и услуги',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 18),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Записаться',
                      style: TextStyle(
                          color: AppStyles.primary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded,
                      color: AppStyles.primary, size: 16),
                ]),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 20),

        // ── Кнопка Акции ─────────────────────────────────────────────────
        GestureDetector(
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const PromosScreen())),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
            decoration: AppStyles.cardDecorationFor(context),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppStyles.adaptivePrimaryBg(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.local_offer_rounded,
                    color: AppStyles.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Акции и спецпредложения',
                        style: TextStyle(
                            color: AppStyles.adaptiveTextPrimary(context),
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      promos.isEmpty
                          ? 'Нет активных акций'
                          : '${promos.length} предложени${promos.length == 1 ? "е" : (promos.length < 5 ? "я" : "й")}',
                      style: AppStyles.bodySmall.copyWith(
                          color: AppStyles.adaptiveTextSecondary(context)),
                    ),
                  ])),
              const SizedBox(width: 8),
              if (promos.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: AppStyles.primaryGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${promos.length}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded,
                  color: AppStyles.adaptiveTextSecondary(context), size: 20),
            ]),
          ),
        ),
        const SizedBox(height: 28),

        // ── Как это работает ─────────────────────────────────────────────
        const _SectionHeader('Как записаться'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: AppStyles.cardDecorationFor(context),
          child: const Column(children: [
            _StepRow('1', 'Укажите данные авто',
                'Марка, модель и государственный номер'),
            _StepRow(
                '2', 'Выберите услуги', 'Тип мойки и дополнительные опции'),
            _StepRow('3', 'Выберите дату и время',
                'Удобный слот из доступного расписания'),
            _StepRow('4', 'Подтвердите запись',
                'Проверьте итог и нажмите «Записаться»'),
          ]),
        ),
      ]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) => Text(title,
      style: AppStyles.headingMedium
          .copyWith(color: AppStyles.adaptiveTextPrimary(context)));
}

class _StepRow extends StatelessWidget {
  final String number, title, subtitle;
  const _StepRow(this.number, this.title, this.subtitle);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, gradient: AppStyles.primaryGradient),
            child: Center(
                child: Text(number,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: TextStyle(
                        color: AppStyles.adaptiveTextPrimary(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: AppStyles.bodySmall.copyWith(
                        color: AppStyles.adaptiveTextSecondary(context))),
              ])),
        ]),
      );
}
