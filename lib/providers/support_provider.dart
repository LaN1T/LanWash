import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
  StreamSubscription? _wsSubscription;
  Timer? _reconnectTimer;
  Timer? _pollingTimer;
  int? _activeChatId;
  bool _shouldReconnect = false;
  int _reconnectAttempt = 0;

  final ValueNotifier<bool> isConnected = ValueNotifier(false);

  String? _lastStatus;
  bool? _lastIsAdmin;

  StreamSubscription<int>? _pushSub;

  SupportProvider() {
    _pushSub = NotificationService().onSupportChatMessage.listen((chatId) {
      if (_lastIsAdmin != null) {
        loadChats(status: _lastStatus, isAdmin: _lastIsAdmin!);
      }
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
      _error =
          _mapError(e, 'Не удалось загрузить чаты. Проверьте подключение.');
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> loadMessages(int chatId, {bool silent = false}) async {
    if (!silent) {
      _loading = true;
      notifyListeners();
    }
    _error = null;
    try {
      final loaded = await _api.getSupportMessages(chatId);
      // Merge with any messages already received via WebSocket while loading
      final merged = [..._messages, ...loaded];
      _messages = _dedupeAndSortMessages(merged);
      await _api.markSupportChatRead(chatId);
      notifyListeners();
    } catch (e) {
      _error = _mapError(
          e, 'Не удалось загрузить сообщения. Проверьте подключение.');
      if (!silent) notifyListeners();
    }
    if (!silent) {
      _loading = false;
      notifyListeners();
    }
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
        final isAdmin = _lastIsAdmin ?? false;
        _chats[idx] = old.copyWith(
          unreadByAdmin: isAdmin ? 0 : old.unreadByAdmin,
          unreadByUser: !isAdmin ? 0 : old.unreadByUser,
        );
        notifyListeners();
      }
    }
    return ok;
  }

  void connectToChat(int chatId) {
    disconnect();
    _activeChatId = chatId;
    _shouldReconnect = true;
    _reconnectAttempt = 0;
    _messages = [];
    _connectWs(chatId);
    _startPolling(chatId);
  }

  void _startPolling(int chatId) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_activeChatId == chatId) {
        loadMessages(chatId, silent: true);
      }
    });
  }

  Future<void> _connectWs(int chatId) async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    try {
      final token = await ApiClient.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[SupportProvider] WebSocket skipped: no token');
        isConnected.value = false;
        return;
      }
      final base = AppConfig.baseUrl;
      final host =
          base.endsWith('/api') ? base.substring(0, base.length - 4) : base;
      final wsUrl =
          '${host.replaceFirst('http', 'ws')}/ws/support/chats/$chatId';
      debugPrint('[SupportProvider] WebSocket connecting to $wsUrl');
      _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _wsChannel!.sink.add(jsonEncode({'type': 'auth', 'token': token}));
      isConnected.value = true;
      _reconnectAttempt = 0;
      debugPrint('[SupportProvider] WebSocket connected, auth sent');
      _wsSubscription = _wsChannel!.stream.listen(
        (event) {
          debugPrint('[SupportProvider] WebSocket event: $event');
          try {
            final data = jsonDecode(event as String) as Map<String, dynamic>;
            final type = data['type'] as String?;
            if (type == 'new_message') {
              final msg =
                  SupportMessage.fromMap(data['data'] as Map<String, dynamic>);
              if (_activeChatId == chatId &&
                  !_messages.any((m) => m.id == msg.id)) {
                _messages.add(msg);
                _bumpChat(chatId, msg.content);
                notifyListeners();
                debugPrint(
                    '[SupportProvider] WebSocket new_message added: ${msg.content}');
              }
            } else if (type == 'status_update') {
              if (_lastIsAdmin != null) {
                loadChats(status: _lastStatus, isAdmin: _lastIsAdmin!);
              }
            }
          } catch (e, st) {
            debugPrint(
                '[SupportProvider] WebSocket event handling error: $e\n$st');
          }
        },
        onError: (e) {
          debugPrint('[SupportProvider] WebSocket onError: $e');
          isConnected.value = false;
          _scheduleReconnect(chatId);
        },
        onDone: () {
          debugPrint('[SupportProvider] WebSocket onDone');
          isConnected.value = false;
          _scheduleReconnect(chatId);
        },
      );
    } catch (e) {
      debugPrint('[SupportProvider] WebSocket connect exception: $e');
      isConnected.value = false;
      _scheduleReconnect(chatId);
    }
  }

  void _scheduleReconnect(int chatId) {
    if (_activeChatId != chatId || !_shouldReconnect) return;
    _reconnectTimer?.cancel();
    final delaySeconds =
        [1, 2, 4, 8, 16, 30][(_reconnectAttempt < 5) ? _reconnectAttempt : 5];
    _reconnectAttempt++;
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (_activeChatId == chatId && _shouldReconnect) {
        _connectWs(chatId);
      }
    });
  }

  void disconnect() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    try {
      _wsSubscription?.cancel();
    } catch (_) {}
    _wsSubscription = null;
    try {
      _wsChannel?.sink.close();
    } catch (_) {}
    _wsChannel = null;
    _activeChatId = null;
    isConnected.value = false;
  }

  List<SupportMessage> _dedupeAndSortMessages(List<SupportMessage> list) {
    final seen = <int>{};
    final result = <SupportMessage>[];
    for (final m in list) {
      if (seen.add(m.id)) result.add(m);
    }
    result.sort((a, b) {
      final da = DateTime.tryParse(a.createdAt) ?? DateTime(1970);
      final db = DateTime.tryParse(b.createdAt) ?? DateTime(1970);
      return da.compareTo(db);
    });
    return result;
  }

  String _mapError(Object e, String fallback) {
    if (e is FormatException) return 'Некорректный ответ сервера.';
    if (e is TimeoutException) {
      return 'Превышено время ожидания. Проверьте подключение.';
    }
    final msg = e.toString().toLowerCase();
    if (msg.contains('socket') ||
        msg.contains('connection') ||
        msg.contains('failed host lookup') ||
        msg.contains('network') ||
        msg.contains('internet')) {
      return 'Не удалось подключиться к серверу. Проверьте интернет-соединение.';
    }
    return fallback;
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
    isConnected.dispose();
    super.dispose();
  }
}
