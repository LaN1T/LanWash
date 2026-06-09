import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/config.dart';
import '../core/api_client.dart';
import '../models/support_chat.dart';
import '../models/support_message.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

class SupportProvider extends ChangeNotifier {
  final _api = ApiService();

  List<SupportChat> _chats = [];
  List<SupportChat> get chats => _chats;

  List<SupportMessage> _messages = [];
  List<SupportMessage> get messages => _messages;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  int get unreadAdminCount => _chats.fold(0, (sum, c) => sum + c.unreadByAdmin);
  int get unreadClientCount => _chats.fold(0, (sum, c) => sum + c.unreadByUser);

  WebSocketChannel? _wsChannel;
  int? _activeChatId;

  String? _lastStatus;
  bool _lastIsAdmin = false;

  StreamSubscription<int>? _pushSub;

  SupportProvider() {
    _pushSub = NotificationService().onSupportChatMessage.listen((chatId) {
      loadChats(status: _lastStatus, isAdmin: _lastIsAdmin);
      if (_activeChatId == chatId) {
        loadMessages(chatId);
      }
    });
  }

  Future<void> loadChats({String? status, bool isAdmin = false}) async {
    _lastStatus = status;
    _lastIsAdmin = isAdmin;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _chats = isAdmin
          ? await _api.getAllSupportChats(status: status)
          : await _api.getMySupportChats();
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> loadMessages(int chatId) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _messages = await _api.getSupportMessages(chatId);
      await _api.markSupportChatRead(chatId);
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  Future<SupportChat?> createChat(String firstMessage) async {
    final chat = await _api.createSupportChat(firstMessage);
    if (chat != null) {
      _chats.insert(0, chat);
      notifyListeners();
    }
    return chat;
  }

  Future<SupportMessage?> sendMessage(int chatId, String content) async {
    final msg = await _api.sendSupportMessage(chatId, content);
    if (msg != null) {
      _messages.add(msg);
      _bumpChat(chatId, content);
      notifyListeners();
    }
    return msg;
  }

  Future<String?> generateAiDraft(int chatId) async {
    return _api.generateAiDraft(chatId);
  }

  Future<bool> assignChat(int chatId) async {
    final ok = await _api.assignSupportChat(chatId);
    if (ok) await loadChats(status: _lastStatus, isAdmin: true);
    return ok;
  }

  Future<bool> closeChat(int chatId) async {
    final ok = await _api.closeSupportChat(chatId);
    if (ok) await loadChats(status: _lastStatus, isAdmin: true);
    return ok;
  }

  Future<bool> markChatRead(int chatId) async {
    final ok = await _api.markSupportChatRead(chatId);
    if (ok) {
      final idx = _chats.indexWhere((c) => c.id == chatId);
      if (idx >= 0) {
        final old = _chats[idx];
        _chats[idx] = old.copyWith(
          unreadByAdmin: _lastIsAdmin ? 0 : old.unreadByAdmin,
          unreadByUser: !_lastIsAdmin ? 0 : old.unreadByUser,
        );
        notifyListeners();
      }
    }
    return ok;
  }

  void connectToChat(int chatId) {
    disconnect();
    _activeChatId = chatId;
    _connectWs(chatId);
  }

  Future<void> _connectWs(int chatId) async {
    try {
      final token = await ApiClient.getToken();
      if (token == null || token.isEmpty) return;
      final base = AppConfig.baseUrl;
      final host = base.endsWith('/api') ? base.substring(0, base.length - 4) : base;
      final wsUrl = '${host.replaceFirst('http', 'ws')}/ws/support/chats/$chatId?token=$token';
      _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _wsChannel!.stream.listen(
        (event) {
          try {
            final data = jsonDecode(event as String) as Map<String, dynamic>;
            final type = data['type'] as String?;
            if (type == 'new_message') {
              final msg = SupportMessage.fromMap(data['data'] as Map<String, dynamic>);
              if (_activeChatId == chatId) {
                _messages.add(msg);
                _bumpChat(chatId, msg.content);
                notifyListeners();
              }
            } else if (type == 'status_update') {
              loadChats(status: _lastStatus, isAdmin: _lastIsAdmin);
            }
          } catch (_) {}
        },
        onError: (_) {},
        onDone: () {},
      );
    } catch (_) {}
  }

  void disconnect() {
    try {
      _wsChannel?.sink.close();
    } catch (_) {}
    _wsChannel = null;
    _activeChatId = null;
  }

  void _bumpChat(int chatId, String? preview) {
    final idx = _chats.indexWhere((c) => c.id == chatId);
    if (idx >= 0) {
      final old = _chats[idx];
      _chats.removeAt(idx);
      _chats.insert(
        0,
        old.copyWith(
          lastMessagePreview: preview ?? old.lastMessagePreview,
          lastMessageAt: DateTime.now().toIso8601String(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _pushSub?.cancel();
    disconnect();
    super.dispose();
  }
}
