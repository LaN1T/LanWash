import 'package:flutter/material.dart';
import '../../app_styles.dart';
import 'subscription_hub_screen.dart';

class SubscriptionSuccessScreen extends StatelessWidget {
  final String subscriptionName;
  final int price;

  const SubscriptionSuccessScreen({
    super.key,
    required this.subscriptionName,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: AppStyles.pagePadding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: AppStyles.successBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    size: 64, color: AppStyles.success),
              ),
              const SizedBox(height: 32),
              Text(
                'Абонемент оформлен!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppStyles.adaptiveTextPrimary(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                subscriptionName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppStyles.adaptiveTextSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Оплачено: $price ₽',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppStyles.primary,
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SubscriptionHubScreen()),
                    (route) => route.isFirst,
                  );
                },
                style: AppStyles.primaryButton.copyWith(
                  minimumSize:
                      const WidgetStatePropertyAll(Size(double.infinity, 52)),
                ),
                child: const Text('К моим абонементам'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
