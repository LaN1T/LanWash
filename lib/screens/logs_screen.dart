import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_styles.dart';
import '../models/log_entry.dart';
import '../services/log_service.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});
  @override State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  List<LogEntry> _logs = [];
  bool _loading = true;
  String _filterUser = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final logs = await LogService.instance.getAll();
    if (mounted) setState(() { _logs = logs; _loading = false; });
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Очистить журнал?'),
        content: const Text('Все записи журнала будут удалены безвозвратно.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppStyles.danger, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Очистить'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await LogService.instance.clearAll();
      _load();
    }
  }

  List<LogEntry> get _filtered {
    if (_filterUser.isEmpty) return _logs;
    return _logs.where((l) =>
        l.username.contains(_filterUser.toLowerCase())).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: AppStyles.bgPage,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppStyles.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppStyles.border),
        ),
        title: const Text('Журнал действий',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
            tooltip: 'Обновить',
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, color: AppStyles.danger),
            onPressed: _confirmClear,
            tooltip: 'Очистить журнал',
          ),
        ],
      ),
      body: Column(children: [
        // Поиск по пользователю
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _filterUser = v),
            decoration: AppStyles.inputDecoration(
                'Фильтр по логину', icon: Icons.person_search_outlined),
            style: AppStyles.bodyLarge,
          ),
        ),
        // Счётчик
        if (!_loading)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(children: [
              Text('Записей: ${filtered.length}',
                  style: AppStyles.bodySmall),
              if (_filterUser.isNotEmpty) ...[ 
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    _searchCtrl.clear();
                    setState(() => _filterUser = '');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppStyles.primaryBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('× сбросить',
                        style: TextStyle(color: AppStyles.primary,
                            fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ]),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppStyles.primary))
              : filtered.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.history_rounded,
                      size: 56, color: AppStyles.textSecondary),
                  const SizedBox(height: 12),
                  Text(_filterUser.isEmpty ? 'Журнал пуст' : 'Нет записей',
                      style: const TextStyle(color: AppStyles.textSecondary,
                          fontSize: 16, fontWeight: FontWeight.w500)),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _LogCard(entry: filtered[i]),
                ),
        ),
      ]),
    );
  }
}

class _LogCard extends StatelessWidget {
  final LogEntry entry;
  const _LogCard({required this.entry});

  Color get _actionColor {
    final a = entry.action;
    if (a.contains('Вход') && a.contains('Неудачн')) return AppStyles.danger;
    if (a.contains('Вход')) return AppStyles.success;
    if (a.contains('Выход')) return AppStyles.textSecondary;
    if (a.contains('Регистрация')) return AppStyles.primary;
    if (a.contains('Удален')) return AppStyles.danger;
    if (a.contains('Создание')) return AppStyles.success;
    if (a.contains('Редактир')) return AppStyles.warning;
    if (a.contains('избранное')) return AppStyles.favorite;
    return AppStyles.textSecondary;
  }

  IconData get _actionIcon {
    final a = entry.action;
    if (a.contains('Вход') && a.contains('Неудачн')) return Icons.lock_open_rounded;
    if (a.contains('Вход')) return Icons.login_rounded;
    if (a.contains('Выход')) return Icons.logout_rounded;
    if (a.contains('Регистрация')) return Icons.person_add_rounded;
    if (a.contains('Удален')) return Icons.delete_outline_rounded;
    if (a.contains('Создание')) return Icons.add_circle_outline_rounded;
    if (a.contains('Редактир')) return Icons.edit_outlined;
    if (a.contains('избранное')) return Icons.star_outline_rounded;
    if (a.contains('профиль')) return Icons.manage_accounts_outlined;
    return Icons.info_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final color = _actionColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: AppStyles.cardDecoration,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_actionIcon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppStyles.primaryBg,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(entry.username,
                    style: const TextStyle(color: AppStyles.primary,
                        fontSize: 11, fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              Text(
                DateFormat('d MMM, HH:mm', 'ru').format(entry.timestamp),
                style: AppStyles.bodySmall,
              ),
            ]),
            const SizedBox(height: 5),
            Text(entry.action, style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w600)),
            if (entry.details.isNotEmpty) ...[ 
              const SizedBox(height: 2),
              Text(entry.details, style: AppStyles.bodySmall),
            ],
          ])),
        ]),
      ),
    );
  }
}
