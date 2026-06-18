import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app_styles.dart';
import '../../core/offline/database.dart';
import '../../core/offline/offline_repository.dart';
import '../../core/service_locator.dart';
import '../../providers/offline_provider.dart';

/// Screen that shows pending offline actions and allows the user to trigger
/// a manual sync.
class SyncQueueScreen extends StatefulWidget {
  const SyncQueueScreen({super.key});

  @override
  State<SyncQueueScreen> createState() => _SyncQueueScreenState();
}

class _SyncQueueScreenState extends State<SyncQueueScreen> {
  late Future<List<PendingAction>> _actionsFuture;

  @override
  void initState() {
    super.initState();
    _loadActions();
  }

  void _loadActions() {
    _actionsFuture = sl<OfflineRepository>().getPendingActions();
  }

  Future<void> _sync() async {
    final provider = context.read<OfflineProvider>();
    final failed = await provider.sync();
    if (!mounted) return;
    setState(_loadActions);
    final messenger = ScaffoldMessenger.of(context);
    if (failed == 0) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Синхронизация завершена'),
          backgroundColor: AppStyles.success,
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Не удалось отправить $failed действий'),
          backgroundColor: AppStyles.warning,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OfflineProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Очередь синхронизации'),
        elevation: 0,
      ),
      body: RefreshIndicator(
        color: AppStyles.primary,
        onRefresh: () async {
          await provider.refresh();
          setState(_loadActions);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StatusCard(
              isOnline: provider.isOnline,
              pendingCount: provider.pendingCount,
              isSyncing: provider.isSyncing,
              onSync: _sync,
            ),
            const SizedBox(height: 16),
            _buildActionsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsList() {
    return FutureBuilder<List<PendingAction>>(
      future: _actionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: AppStyles.primary),
            ),
          );
        }

        final actions = snapshot.data ?? [];
        if (actions.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_done_outlined,
                  size: 56,
                  color: AppStyles.adaptiveTextSecondary(context)
                      .withValues(alpha: 0.4),
                ),
                const SizedBox(height: 12),
                Text(
                  'Очередь пуста',
                  style: AppStyles.headingMedium.copyWith(
                    color: AppStyles.adaptiveTextSecondary(context),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Все изменения синхронизированы',
                  style: AppStyles.bodyMedium.copyWith(
                    color: AppStyles.adaptiveTextSecondary(context),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ожидают отправки (${actions.length})',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppStyles.adaptiveTextPrimary(context),
              ),
            ),
            const SizedBox(height: 10),
            ...actions.map((action) => _ActionTile(action: action)),
          ],
        );
      },
    );
  }
}

class _StatusCard extends StatelessWidget {
  final bool isOnline;
  final int pendingCount;
  final bool isSyncing;
  final VoidCallback onSync;

  const _StatusCard({
    required this.isOnline,
    required this.pendingCount,
    required this.isSyncing,
    required this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    final dark = AppStyles.isDark(context);
    final statusColor = isOnline ? AppStyles.success : AppStyles.danger;
    final statusIcon =
        isOnline ? Icons.cloud_done_outlined : Icons.cloud_off_outlined;
    final statusText =
        isOnline ? 'Подключение к сети есть' : 'Нет подключения к сети';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppStyles.adaptiveCard(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppStyles.adaptiveBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: dark ? 0.2 : 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: statusColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppStyles.adaptiveTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pendingCount == 0
                          ? 'Всё синхронизировано'
                          : 'Ожидает синхронизации: $pendingCount',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppStyles.adaptiveTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (pendingCount > 0) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isSyncing ? null : onSync,
                icon: isSyncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cloud_upload_outlined, size: 20),
                label: Text(isSyncing ? 'Синхронизация…' : 'Синхронизировать'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppStyles.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppStyles.primary.withValues(alpha: 0.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final PendingAction action;

  const _ActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    final createdAt = DateTime.tryParse(action.createdAtStr);
    final timeText = createdAt != null
        ? DateFormat('dd.MM.yyyy HH:mm').format(createdAt)
        : action.createdAtStr;

    Color methodColor;
    switch (action.method.toUpperCase()) {
      case 'POST':
        methodColor = AppStyles.success;
        break;
      case 'PUT':
        methodColor = AppStyles.warning;
        break;
      case 'DELETE':
        methodColor = AppStyles.danger;
        break;
      default:
        methodColor = AppStyles.adaptiveTextSecondary(context);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppStyles.adaptiveCard(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppStyles.adaptiveBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: methodColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  action.method.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: methodColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  action.action,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppStyles.adaptiveTextPrimary(context),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            action.endpoint,
            style: TextStyle(
              fontSize: 13,
              color: AppStyles.adaptiveTextSecondary(context),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 14,
                color: AppStyles.adaptiveTextSecondary(context),
              ),
              const SizedBox(width: 4),
              Text(
                timeText,
                style: TextStyle(
                  fontSize: 12,
                  color: AppStyles.adaptiveTextSecondary(context),
                ),
              ),
              const Spacer(),
              if (action.retryCount > 0)
                Text(
                  'Попыток: ${action.retryCount}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppStyles.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
