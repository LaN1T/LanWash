import 'package:flutter/material.dart';
import '../../app_styles.dart';

/// Единый логотип-портрет для splash, drawer, login и т.д.
class LanWashLogo extends StatelessWidget {
  final double iconSize;
  final double circleSize;
  final double? shadowBlur;
  final bool showTitle;
  final bool showSubtitle;
  final bool showLoader;

  const LanWashLogo({
    super.key,
    this.iconSize = 64,
    this.circleSize = 120,
    this.shadowBlur = 28,
    this.showTitle = true,
    this.showSubtitle = true,
    this.showLoader = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppStyles.adaptiveTextPrimary(context);
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha:0.6)
        : AppStyles.adaptiveTextSecondary(context).withValues(alpha:0.7);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Иконка на синем градиенте ──
        Container(
          width: circleSize,
          height: circleSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppStyles.primaryGradient,
            boxShadow: shadowBlur != null
                ? [
                    BoxShadow(
                      color: AppStyles.primary.withValues(alpha:0.3),
                      blurRadius: shadowBlur!,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            Icons.local_car_wash,
            color: Colors.white,
            size: iconSize,
          ),
        ),
        if (showTitle) ...[
          const SizedBox(height: 32),
          Text(
            'LanWash',
            style: TextStyle(
              color: textColor,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ],
        if (showSubtitle) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Приложение для записи на автомойку',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: subtitleColor,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
        if (showLoader) ...[
          const SizedBox(height: 48),
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppStyles.primary),
            strokeWidth: 3,
          ),
        ],
      ],
    );
  }
}

/// Простой splash для экрана инициализации auth
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0a0a0a) : Colors.white,
      body: const Center(child: LanWashLogo()),
    );
  }
}

/// Анимированный splash для красивого старта
class AnimatedSplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const AnimatedSplashScreen({super.key, required this.onComplete});

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutCubic),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOut),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );

    _startAnimation();
  }

  Future<void> _startAnimation() async {
    await Future.delayed(const Duration(milliseconds: 500));
    await _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    await _textController.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) widget.onComplete();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0a0a0a) : Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _logoController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _logoScale.value,
                  child: Opacity(
                    opacity: _logoOpacity.value,
                    child: child,
                  ),
                );
              },
              child: const LanWashLogo(
                showTitle: false,
                showSubtitle: false,
                showLoader: false,
              ),
            ),
            const SizedBox(height: 32),
            AnimatedBuilder(
              animation: _textController,
              builder: (context, child) {
                return Opacity(
                  opacity: _textOpacity.value,
                  child: child,
                );
              },
              child: Text(
                'LanWash',
                style: TextStyle(
                  color: isDark ? Colors.white : AppStyles.adaptiveTextPrimary(context),
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 8),
            AnimatedBuilder(
              animation: _textController,
              builder: (context, child) {
                return Opacity(
                  opacity: _textOpacity.value,
                  child: child,
                );
              },
              child: Text(
                'Приложение для записи на автомойку',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withValues(alpha:0.6)
                      : AppStyles.adaptiveTextSecondary(context).withValues(alpha:0.7),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
