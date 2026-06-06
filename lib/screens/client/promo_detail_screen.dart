import 'package:flutter/material.dart';
import '../../app_styles.dart';
import '../../models/promo.dart';
import 'booking_wizard_screen.dart';

class PromoDetailScreen extends StatelessWidget {
  final Promo promo;
  const PromoDetailScreen({super.key, required this.promo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyles.adaptiveBgPage(context),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: AppStyles.primaryGradient,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha:0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('СПЕЦПРЕДЛОЖЕНИЕ',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1)),
                    ),
                    const SizedBox(height: 8),
                    Text(promo.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Описание',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Text(promo.description,
                      style: AppStyles.bodyLarge.copyWith(
                          height: 1.6, color: AppStyles.adaptiveTextSecondary(context))),
                  const SizedBox(height: 32),
                  Row(children: [
                    _InfoCard(
                        Icons.access_time_rounded, '${promo.duration} мин'),
                    const SizedBox(width: 16),
                    _InfoCard(Icons.local_offer_rounded, '${promo.price} ₽'),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha:0.05),
                blurRadius: 10,
                offset: const Offset(0, -5))
          ],
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => BookingWizardScreen(initialPromo: promo))),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppStyles.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: const Text('Записаться по акции',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoCard(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppStyles.adaptiveBorder(context)),
          ),
          child: Column(children: [
            Icon(icon, color: AppStyles.primary),
            const SizedBox(height: 8),
            Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}
