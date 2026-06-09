import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_styles.dart';
import '../../models/support_chat.dart';
import '../../models/support_message.dart';
import '../../providers/auth_provider.dart';
import '../../providers/support_provider.dart';

class SupportChatScreen extends StatefulWidget {
  final SupportChat chat;
  const SupportChatScreen({super.key, required this.chat});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late SupportChat _chat;
  String? _aiDraft;
  bool _aiLoading = false;
  int _lastMessageCount = 0;

  late SupportProvider _provider;

  @override
  void initState() {
    super.initState();
    _chat = widget.chat;
    _provider = context.read<SupportProvider>();
    _lastMessageCount = _provider.messages.length;
    _provider.addListener(_onProviderChanged);
    _provider.loadMessages(_chat.id).then((_) {
      if (!mounted) return;
      _provider.connectToChat(_chat.id);
      _provider.markChatRead(_chat.id);
      _scrollToBottom();
    });
  }

  void _onProviderChanged() {
    if (!mounted) return;
    SupportChat? updated;
    for (final c in _provider.chats) {
      if (c.id == _chat.id) {
        updated = c;
        break;
      }
    }
    if (updated != null && !identical(updated, _chat)) {
      setState(() => _chat = updated!);
    }
    final newCount = _provider.messages.length;
    if (newCount > _lastMessageCount) {
      _lastMessageCount = newCount;
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    _provider.removeListener(_onProviderChanged);
    _provider.disconnect();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _generateDraft() async {
    setState(() => _aiLoading = true);
    final draft = await context.read<SupportProvider>().generateAiDraft(_chat.id);
    if (mounted) {
      setState(() {
        _aiDraft = draft;
        _aiLoading = false;
      });
    }
  }

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await context.read<SupportProvider>().sendMessage(_chat.id, trimmed);
    _controller.clear();
    if (mounted) setState(() => _aiDraft = null);
    _scrollToBottom();
  }

  void _applyQuickReply(String text) {
    _controller.text = text;
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

  Future<void> _assign() async {
    final ok = await _provider.assignChat(_chat.id);
    if (!mounted) return;
    if (ok) {
      final auth = context.read<AuthProvider>();
      setState(() {
        _chat = _chat.copyWith(
          status: 'admin_assigned',
          assignedAdminId: auth.user?.id,
          assignedAdminName: auth.user?.displayName,
        );
      });
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Чат назначен на вас' : 'Не удалось назначить чат'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _close() async {
    final ok = await context.read<SupportProvider>().closeChat(_chat.id);
    if (!mounted) return;
    if (ok) Navigator.pop(context);
  }

  void _showClientInfo() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Клиент', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.person),
                title: Text(_chat.userName),
                subtitle: Text(_chat.userPhone ?? 'Телефон не указан'),
              ),
              const ListTile(
                leading: Icon(Icons.directions_car),
                title: Text('Модель авто'),
                subtitle: Text('—'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SupportProvider>();
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_chat.userName),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Клиент',
            onPressed: _showClientInfo,
          ),
          if (_chat.status != 'closed')
            TextButton(
              onPressed: _assign,
              child: const Text('Назначить', style: TextStyle(color: Colors.white)),
            ),
          if (_chat.status != 'closed')
            TextButton(
              onPressed: _close,
              child: const Text('Закрыть', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: provider.messages.length,
              itemBuilder: (context, index) {
                return _MessageBubble(message: provider.messages[index]);
              },
            ),
          ),
          if (_aiDraft != null)
            _AiDraftCard(
              draft: _aiDraft!,
              onEdit: (v) => setState(() => _aiDraft = v),
              onSend: () => _send(_aiDraft!),
            ),
          _InputBar(
            controller: _controller,
            onSend: () => _send(_controller.text),
            onAi: _generateDraft,
            onQuickReply: _applyQuickReply,
            aiLoading: _aiLoading,
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
    final isAdmin = message.senderRole == 'admin';
    final isAi = message.senderRole == 'ai';
    final align = isAdmin ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bg = isAdmin
        ? AppStyles.primary
        : isAi
            ? AppStyles.inProgressBg
            : AppStyles.adaptiveCard(context);
    final fg = isAdmin
        ? Colors.white
        : isAi
            ? AppStyles.inProgress
            : AppStyles.adaptiveTextPrimary(context);
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isAdmin ? 16 : 4),
      bottomRight: Radius.circular(isAdmin ? 4 : 16),
    );

    return Align(
      alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
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
                border: isAdmin
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
                      (isAdmin ? 'Администратор' : 'Клиент')),
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

class _AiDraftCard extends StatefulWidget {
  final String draft;
  final ValueChanged<String> onEdit;
  final VoidCallback onSend;

  const _AiDraftCard({
    required this.draft,
    required this.onEdit,
    required this.onSend,
  });

  @override
  State<_AiDraftCard> createState() => _AiDraftCardState();
}

class _AiDraftCardState extends State<_AiDraftCard> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.draft)
      ..selection = TextSelection.collapsed(offset: widget.draft.length);
  }

  @override
  void didUpdateWidget(covariant _AiDraftCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.draft != _controller.text) {
      _controller.text = widget.draft;
      _controller.selection = TextSelection.collapsed(offset: widget.draft.length);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppStyles.inProgressBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppStyles.inProgress.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, size: 16, color: AppStyles.inProgress),
              SizedBox(width: 6),
              Text(
                'Черновик AI',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppStyles.inProgress,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            maxLines: null,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
            ),
            style: TextStyle(color: AppStyles.adaptiveTextPrimary(context)),
            onChanged: widget.onEdit,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: () => widget.onEdit(''),
                child: const Text('Очистить'),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: widget.onSend,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppStyles.inProgress,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Отправить'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onAi;
  final ValueChanged<String> onQuickReply;
  final bool aiLoading;

  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.onAi,
    required this.onQuickReply,
    required this.aiLoading,
  });

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: aiLoading ? null : onAi,
                  icon: aiLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome),
                  color: AppStyles.inProgress,
                  tooltip: 'Сгенерировать ответ AI',
                ),
                IconButton(
                  onPressed: () => _showQuickReplies(context),
                  icon: const Icon(Icons.bolt),
                  color: AppStyles.warning,
                  tooltip: 'Быстрый ответ',
                ),
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
          ],
        ),
      ),
    );
  }

  void _showQuickReplies(BuildContext context) {
    final replies = [
      'Здравствуйте! Чем могу помочь?',
      'Уточните, пожалуйста, детали.',
      'Спасибо за обращение, всё записал.',
      'Приносим извинения за неудобства.',
    ];
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: replies
                .map((r) => ListTile(
                      title: Text(r),
                      onTap: () {
                        Navigator.pop(context);
                        onQuickReply(r);
                      },
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }
}
