import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../app_styles.dart';
import '../../models/support_chat.dart';
import '../../providers/support_provider.dart';
import 'support_chat_screen.dart';

class SupportTicketsScreen extends StatefulWidget {
  const SupportTicketsScreen({super.key});

  @override
  State<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends State<SupportTicketsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _pollTimer;

  static const _statuses = ['', 'open', 'admin_assigned', 'closed'];
  static const _labels = ['Все', 'Новые', 'В работе', 'Закрыты'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statuses.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _load());
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) _load();
  }

  void _load() {
    final status = _statuses[_tabController.index];
    context.read<SupportProvider>().loadChats(
          status: status.isEmpty ? null : status,
          isAdmin: true,
        );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Поддержка'),
        bottom: TabBar(
          controller: _tabController,
          tabs: _labels.map((l) => Tab(text: l)).toList(),
        ),
      ),
      body: Consumer<SupportProvider>(
        builder: (context, provider, _) {
          if (provider.loading && provider.chats.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppStyles.primary),
            );
          }
          if (provider.error != null && provider.chats.isEmpty) {
            return Center(
              child: Text(
                provider.error!,
                style: const TextStyle(color: AppStyles.danger),
              ),
            );
          }
          return RefreshIndicator(
            color: AppStyles.primary,
            onRefresh: () => provider.loadChats(
              status: _statuses[_tabController.index].isEmpty
                  ? null
                  : _statuses[_tabController.index],
              isAdmin: true,
            ),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: provider.chats.length,
              itemBuilder: (context, index) {
                final chat = provider.chats[index];
                return _ChatTile(chat: chat);
              },
            ),
          );
        },
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final SupportChat chat;
  const _ChatTile({required this.chat});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: AppStyles.primary.withValues(alpha: 0.12),
        child: Text(
          chat.userName.isNotEmpty ? chat.userName[0].toUpperCase() : '?',
          style: const TextStyle(
            color: AppStyles.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              chat.userName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          _StatusBadge(status: chat.status),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            chat.lastMessagePreview ?? 'Нет сообщений',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AppStyles.adaptiveTextSecondary(context)),
          ),
          if (chat.lastMessageAt != null)
            Text(
              _formatTime(chat.lastMessageAt!),
              style: TextStyle(
                fontSize: 11,
                color: AppStyles.adaptiveTextMuted(context),
              ),
            ),
        ],
      ),
      trailing: chat.unreadByAdmin > 0
          ? Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppStyles.danger,
                shape: BoxShape.circle,
              ),
            )
          : null,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SupportChatScreen(chat: chat)),
      ),
    );
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return DateFormat('dd.MM.yyyy HH:mm').format(dt);
    } catch (_) {
      return iso;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'open' => ('Новый', AppStyles.warning),
      'ai_handled' => ('AI', AppStyles.inProgress),
      'waiting_admin' => ('Ожидает', AppStyles.warning),
      'admin_assigned' => ('В работе', AppStyles.primary),
      'closed' => ('Закрыт', AppStyles.success),
      _ => (status, AppStyles.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
