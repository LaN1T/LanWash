import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../app_styles.dart';
import '../../models/referral.dart';
import '../../services/api_service.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  ReferralStats? _stats;
  List<Referral> _referrals = [];
  bool _loading = true;
  bool _claiming = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final api = context.read<ApiService>();
    final stats = await api.getReferralStats();
    final list = await api.getReferrals();
    if (mounted) {
      setState(() {
        _stats = stats;
        _referrals = list;
        _loading = false;
      });
    }
  }

  Future<void> _claimRewards() async {
    setState(() => _claiming = true);
    final api = context.read<ApiService>();
    final claimed = await api.claimRewards();
    if (!mounted) return;
    setState(() => _claiming = false);

    if (claimed != null && claimed > 0) {
      _showSnack('Награды получены: $claimed');
      await _loadData();
    } else if (claimed == 0) {
      _showSnack('Нет доступных наград');
    } else {
      _showSnack('Ошибка получения наград', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppStyles.danger : AppStyles.success,
    ));
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    _showSnack('Код скопирован');
  }

  void _shareCode(String code) {
    Share.share('Запишись на мойку в LanWash! Мой код: $code');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyles.adaptiveBgPage(context),
      appBar: AppBar(
        backgroundColor: AppStyles.adaptiveBgPage(context),
        foregroundColor: AppStyles.adaptiveTextPrimary(context),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppStyles.adaptiveBorder(context)),
        ),
        title: const Text('Реферальная программа',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppStyles.primary))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppStyles.primary,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildCodeCard(),
                  const SizedBox(height: 20),
                  _buildStatsCard(),
                  const SizedBox(height: 20),
                  if (_stats != null && _stats!.pendingRewards > 0) ...[
                    _buildClaimButton(),
                    const SizedBox(height: 20),
                  ],
                  _buildReferralsList(),
                ],
              ),
            ),
    );
  }

  Widget _buildCodeCard() {
    final code = _stats?.referralCode ?? '';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppStyles.primaryCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Ваш реферальный код',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Text(
              code.isEmpty ? '—' : code,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: code.isEmpty ? null : () => _copyCode(code),
                  icon: const Icon(Icons.copy, size: 18, color: Colors.white),
                  label: const Text('Копировать',
                      style: TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white54),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: code.isEmpty ? null : () => _shareCode(code),
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Поделиться'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppStyles.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    final stats = _stats;
    if (stats == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppStyles.cardDecorationFor(context),
      child: Row(
        children: [
          _statItem('${stats.totalReferrals}', 'Приглашено'),
          Container(
              width: 1,
              height: 32,
              color: AppStyles.adaptiveBorder(context)),
          _statItem('${stats.claimedRewards}', 'Награды получено'),
          Container(
              width: 1,
              height: 32,
              color: AppStyles.adaptiveBorder(context)),
          _statItem('${stats.pendingRewards}', 'Ожидают',
              color: stats.pendingRewards > 0 ? AppStyles.warning : null),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label, {Color? color}) => Expanded(
        child: Column(children: [
          Text(value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color ?? AppStyles.adaptiveTextPrimary(context),
              )),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: AppStyles.adaptiveTextSecondary(context),
              )),
        ]),
      );

  Widget _buildClaimButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _claiming ? null : _claimRewards,
        icon: _claiming
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.card_giftcard, size: 18),
        label: Text(_claiming ? 'Получение...' : 'Получить награды'),
        style: AppStyles.goldButton,
      ),
    );
  }

  Widget _buildReferralsList() {
    if (_referrals.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: AppStyles.cardDecorationFor(context),
        child: Column(
          children: [
            Icon(Icons.people_outline,
                size: 40, color: AppStyles.adaptiveTextMuted(context)),
            const SizedBox(height: 12),
            Text(
              'Вы ещё никого не пригласили',
              style: TextStyle(
                color: AppStyles.adaptiveTextSecondary(context),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Поделитесь кодом с друзьями, чтобы получить награды',
              style: TextStyle(
                color: AppStyles.adaptiveTextMuted(context),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Приглашённые друзья',
          style: TextStyle(
            color: AppStyles.adaptiveTextSecondary(context),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 10),
        ..._referrals.map((r) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: AppStyles.cardDecorationFor(context),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppStyles.adaptivePrimaryBg(context),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_outline,
                        color: AppStyles.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.referredName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppStyles.adaptiveTextPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('d MMM yyyy', 'ru').format(r.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppStyles.adaptiveTextSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: r.rewardClaimed
                          ? AppStyles.successBg
                          : AppStyles.warningBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      r.rewardClaimed ? 'Получено' : 'Ожидает',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: r.rewardClaimed
                            ? AppStyles.success
                            : AppStyles.warning,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}
