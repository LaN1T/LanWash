import 'package:flutter/material.dart';
import '../../app_styles.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';

class ClientSearchScreen extends StatefulWidget {
  const ClientSearchScreen({super.key});

  @override
  State<ClientSearchScreen> createState() => _ClientSearchScreenState();
}

class _ClientSearchScreenState extends State<ClientSearchScreen> {
  final _searchCtrl = TextEditingController();
  List<User> _users = [];
  int _total = 0;
  bool _loading = false;
  String? _error;
  int _offset = 0;
  final int _limit = 20;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) _offset = 0;
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ApiService().searchUsers(
      q: _searchCtrl.text.trim(),
      limit: _limit,
      offset: _offset,
    );
    if (mounted) {
      setState(() {
        _loading = false;
        if (result == null) {
          _error = 'Ошибка загрузки';
        } else {
          final items = (result['items'] as List<dynamic>)
              .map((e) => User.fromMap(e as Map<String, dynamic>))
              .toList();
          if (reset) {
            _users = items;
          } else {
            _users.addAll(items);
          }
          _total = result['total'] ?? 0;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppStyles.isDark(context);
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFF),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text('Поиск клиентов',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Имя, телефон, авто, номер...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _load(reset: true);
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppStyles.adaptiveCard(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: AppStyles.adaptiveBorder(context)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: AppStyles.adaptiveBorder(context)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppStyles.primary),
                ),
              ),
              onSubmitted: (_) => _load(reset: true),
            ),
          ),
          if (_total > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Найдено: $_total',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppStyles.adaptiveTextSecondary(context),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading && _users.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: AppStyles.primary))
                : _error != null
                    ? Center(
                        child: Text(_error!,
                            style: const TextStyle(color: AppStyles.danger)))
                    : _users.isEmpty
                        ? const Center(child: Text('Ничего не найдено'))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: _users.length +
                                (_users.length < _total ? 1 : 0),
                            itemBuilder: (ctx, i) {
                              if (i >= _users.length) {
                                if (!_loading) {
                                  _offset += _limit;
                                  _load();
                                }
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                      child: CircularProgressIndicator(
                                          color: AppStyles.primary)),
                                );
                              }
                              final u = _users[i];
                              return _UserCard(user: u);
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final User user;
  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final dark = AppStyles.isDark(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppStyles.adaptiveBorder(context)),
        boxShadow: [
          if (!dark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppStyles.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppStyles.adaptiveTextPrimary(context),
                  ),
                ),
                const SizedBox(height: 2),
                if (user.phone.isNotEmpty)
                  Text(
                    user.phone,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppStyles.adaptiveTextSecondary(context),
                    ),
                  ),
                if (user.carModel.isNotEmpty || user.carNumber.isNotEmpty)
                  Text(
                    '${user.carModel}${user.carModel.isNotEmpty && user.carNumber.isNotEmpty ? ' · ' : ''}${user.carNumber}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppStyles.adaptiveTextMuted(context),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _roleColor(user.role).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: _roleColor(user.role).withValues(alpha: 0.3)),
            ),
            child: Text(
              _roleLabel(user.role),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _roleColor(user.role),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return AppStyles.danger;
      case UserRole.washer:
        return AppStyles.warning;
      default:
        return AppStyles.primary;
    }
  }

  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Админ';
      case UserRole.washer:
        return 'Мойщик';
      default:
        return 'Клиент';
    }
  }
}
