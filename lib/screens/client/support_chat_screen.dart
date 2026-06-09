import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_styles.dart';
import '../../models/support_chat.dart';
import '../../models/support_message.dart';
import '../../providers/support_provider.dart';

class ClientSupportChatScreen extends StatefulWidget {
  final SupportChat chat;
  const ClientSupportChatScreen({super.key, required this.chat});

  @override
  State<ClientSupportChatScreen> createState() => _ClientSupportChatScreenState();
}

class _ClientSupportChatScreenState extends State<ClientSupportChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final provider = context.read<SupportProvider>();
    provider.loadMessages(widget.chat.id).then((_) {
      provider.connectToChat(widget.chat.id);
      provider.markChatRead(widget.chat.id);
      _scrollToBottom();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scrollToBottom();
  }

  @override
  void dispose() {
    context.read<SupportProvider>().disconnect();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await context.read<SupportProvider>().sendMessage(widget.chat.id, trimmed);
    _controller.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SupportProvider>();
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Поддержка'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: provider.messages.length,
              itemBuilder: (context, index) {
                return _MessageBubble(provider.messages[index]);
              },
            ),
          ),
          _InputBar(
            controller: _controller,
            onSend: () => _send(_controller.text),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final SupportMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isClient = message.senderRole == 'client';
    final isAdmin = message.senderRole == 'admin';
    final isAi = message.senderRole == 'ai';
    final align = isClient ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bg = isClient
        ? AppStyles.primary
        : isAi
            ? AppStyles.inProgressBg
            : AppStyles.adaptiveCard(context);
    final fg = isClient
        ? Colors.white
        : isAi
            ? AppStyles.inProgress
            : AppStyles.adaptiveTextPrimary(context);
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isClient ? 16 : 4),
      bottomRight: Radius.circular(isClient ? 4 : 16),
    );

    return Align(
      alignment: isClient ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Column(
          crossAxisAlignment: align,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: borderRadius,
                border: isClient
                    ? null
                    : Border.all(color: AppStyles.adaptiveBorder(context)),
              ),
              child: Text(
                message.content,
                style: TextStyle(color: fg, fontSize: 15),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              isAi
                  ? 'Ассистент'
                  : (message.senderName ??
                      (isAdmin ? 'Администратор' : 'Вы')),
              style: TextStyle(
                fontSize: 11,
                color: AppStyles.adaptiveTextMuted(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _InputBar({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: AppStyles.adaptiveCard(context),
          border: Border(
            top: BorderSide(color: AppStyles.adaptiveBorder(context)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Сообщение...',
                  filled: true,
                  fillColor: AppStyles.adaptiveBgMuted(context),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onSend,
              icon: const Icon(Icons.send),
              color: AppStyles.primary,
            ),
          ],
        ),
      ),
    );
  }
}
