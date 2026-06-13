import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_styles.dart';
import '../providers/offline_provider.dart';
import '../screens/shared/sync_queue_screen.dart';

/// Displays a compact cloud icon in the app bar when the app is offline or
/// has pending mutations that need to be synced.
class OfflineStatusIndicator extends StatelessWidget {
  const OfflineStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OfflineProvider>();

    if (provider.isOnline && provider.pendingCount == 0) {
      return const SizedBox.shrink();
    }

    final isOffline = !provider.isOnline;
    final icon =
        isOffline ? Icons.cloud_off_outlined : Icons.cloud_upload_outlined;
    final color = isOffline ? AppStyles.danger : AppStyles.warning;
    final tooltip = isOffline
        ? 'Нет подключения к сети'
        : 'Ожидает синхронизации: ${provider.pendingCount}';

    return Center(
      child: IconButton(
        tooltip: tooltip,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SyncQueueScreen()),
          );
        },
        icon: Badge(
          isLabelVisible: provider.pendingCount > 0,
          label: Text('${provider.pendingCount}'),
          backgroundColor: color,
          child: Icon(icon, color: color),
        ),
      ),
    );
  }
}
