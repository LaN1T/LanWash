import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_styles.dart';
import '../../models/subscription.dart';
import '../../services/api_service.dart';
import 'subscription_success_screen.dart';

class SubscriptionCheckoutScreen extends StatefulWidget {
  final String name;
  final String washTypeId;
  final String washTypeName;
  final int price;
  final int originalPrice;
  final int? planId;
  final List<String>? selectedExtras;
  final int? washCount;

  const SubscriptionCheckoutScreen.ready({
    super.key,
    required this.name,
    required this.washTypeId,
    required this.washTypeName,
    required this.price,
    required this.originalPrice,
    required this.planId,
  })  : selectedExtras = null,
        washCount = null;

  const SubscriptionCheckoutScreen.personal({
    super.key,
    required this.name,
    required this.washTypeId,
    required this.washTypeName,
    required this.price,
    required this.originalPrice,
    required this.selectedExtras,
    required this.washCount,
  }) : planId = null;

  @override
  State<SubscriptionCheckoutScreen> createState() =>
      _SubscriptionCheckoutScreenState();
}

class _SubscriptionCheckoutScreenState
    extends State<SubscriptionCheckoutScreen> {
  bool _buying = false;

  bool get _isReady => widget.planId != null;

  Future<void> _pay(BuildContext context) async {
    setState(() => _buying = true);

    try {
      final api = context.read<ApiService>();
      final Subscription? subscription;

      if (_isReady) {
        subscription = await api.buySubscription(
          kind: 'ready',
          ready: {
            'planId': widget.planId,
            'washTypeId': widget.washTypeId,
          },
        );
      } else {
        subscription = await api.buySubscription(
          kind: 'personal',
          personal: {
            'washTypeId': widget.washTypeId,
            'selectedExtras': jsonEncode(widget.selectedExtras ?? []),
            'washCount': widget.washCount,
          },
        );
      }

      if (!context.mounted) return;

      final sub = subscription;
      if (sub != null) {
        await Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => SubscriptionSuccessScreen(
              subscriptionName: sub.name,
              price: sub.price,
            ),
          ),
          (route) => route.isFirst,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось оформить абонемент. Попробуйте позже.'),
            backgroundColor: AppStyles.danger,
          ),
        );
      }
    } on Exception catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppStyles.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _buying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final discount =
        widget.originalPrice > 0 ? widget.originalPrice - widget.price : 0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppStyles.adaptiveBorder(context)),
        ),
        title: const Text('Оформление',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: AppStyles.pagePadding,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppStyles.cardDecorationFor(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppStyles.adaptiveTextPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _Row(label: 'Тип мойки', value: widget.washTypeName),
                      if (!_isReady && widget.washCount != null) ...[
                        const SizedBox(height: 8),
                        _Row(
                            label: 'Количество моек',
                            value: '${widget.washCount}'),
                      ],
                      const Divider(height: 24),
                      _Row(
                        label: 'Сумма',
                        value: '${widget.originalPrice} ₽',
                        valueColor: AppStyles.adaptiveTextPrimary(context),
                      ),
                      if (discount > 0) ...[
                        const SizedBox(height: 8),
                        _Row(
                          label: 'Скидка',
                          value: '-$discount ₽',
                          valueColor: AppStyles.success,
                        ),
                      ],
                      const SizedBox(height: 8),
                      _Row(
                        label: 'К оплате',
                        value: '${widget.price} ₽',
                        valueStyle: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppStyles.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppStyles.warningBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppStyles.warning),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Это демонстрационная оплата. Списание средств не производится.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppStyles.adaptiveTextSecondary(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppStyles.adaptiveCard(context),
              border: Border(
                  top: BorderSide(color: AppStyles.adaptiveBorder(context))),
            ),
            child: SafeArea(
              child: ElevatedButton(
                onPressed: _buying ? null : () => _pay(context),
                style: AppStyles.primaryButton.copyWith(
                  minimumSize:
                      const WidgetStatePropertyAll(Size(double.infinity, 52)),
                ),
                child: _buying
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text('Оплатить ${widget.price} ₽ (демо)'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final TextStyle? valueStyle;

  const _Row({
    required this.label,
    required this.value,
    this.valueColor,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: AppStyles.adaptiveTextSecondary(context),
          ),
        ),
        Text(
          value,
          style: valueStyle ??
              TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppStyles.adaptiveTextPrimary(context),
              ),
        ),
      ],
    );
  }
}
