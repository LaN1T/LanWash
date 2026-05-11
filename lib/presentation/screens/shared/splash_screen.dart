import 'package:flutter/material.dart';
import '../app_styles.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Логотип
            const Icon(
              Icons.local_car_wash,
              color: AppStyles.primary,
              size: 120,
            ),
            const SizedBox(height: 32),
            // Заголовок
            const Text(
              'LanWash',
              style: TextStyle(
                color: AppStyles.textPrimary,
                fontSize: 36,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'LanWash — приложение для записи на автомойку',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppStyles.textSecondary.withOpacity(0.7),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 48),
            // Индикатор
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppStyles.primary),
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}
