import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../app_styles.dart';
import '../../models/support_chat.dart';
import '../../providers/support_provider.dart';
import 'support_chat_screen.dart';

class SupportChatsScreen extends StatefulWidget {
  const SupportChatsScreen({super.key});

  @override
  State<SupportChatsScreen> createState() => _SupportChatsScreenState();
}

class _SupportChatsScreenState extends State<SupportChatsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(context.read<SupportProvider>().loadChats(isAdmin: false));
    });
  }

  Future<void> _createChat() async {
    final provider = context.read<SupportProvider>();
    final chat = await provider.createChat('');
    if (!mounted) return;
    if (chat != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ClientSupportChatScreen(chat: chat)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось создать чат')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Чат с поддержкой'),
      ),
      body: Consumer<SupportProvider>(
        builder: (context, provider, _) {
          if (provider.loading && provider.chats.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppStyles.primary),
            );
          }
          if (provider.chats.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.support_agent_outlined,
                    size: 64,
                    color: AppStyles.adaptiveTextMuted(context),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Нет активных обращений',
                    style: TextStyle(
                      color: AppStyles.adaptiveTextSecondary(context),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _createChat,
                    icon: const Icon(Icons.edit_note),
                    label: const Text('Написать в поддержку'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppStyles.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }
          final chat = provider.chats.first;
          return RefreshIndicator(
            color: AppStyles.primary,
            onRefresh: () => provider.loadChats(isAdmin: false),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _ChatTile(chat: chat),
              ],
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
        child: const Icon(Icons.support_agent, color: AppStyles.primary),
      ),
      title: const Text(
        'Поддержка',
        style: TextStyle(fontWeight: FontWeight.w600),
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
      trailing: chat.unreadByUser > 0
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
        MaterialPageRoute(
          builder: (_) => ClientSupportChatScreen(chat: chat),
        ),
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
