import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../app_styles.dart';
import '../models/note.dart';
import '../models/user.dart';
import '../providers/app_provider.dart';
import '../providers/auth_provider.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});
  @override State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  bool _loading = true;
  List<User> _washers = [];

  String _displayName(String username) {
    final w = _washers.where((w) => w.username == username);
    if (w.isNotEmpty) {
      return w.first.displayName.isNotEmpty ? w.first.displayName : w.first.username;
    }
    return username;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final provider = context.read<AppProvider>();
    if (auth.isAdmin) {
      await provider.loadNotes();
      _washers = await provider.getWashers();
    } else {
      await provider.loadNotes(username: auth.userLogin);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _showAddDialog() {
    final titleCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    String category = 'general';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Новая заметка'),
          content: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: AppStyles.inputDecoration('Заголовок',
                    icon: Icons.title_rounded),
                style: AppStyles.bodyLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: msgCtrl,
                decoration: AppStyles.inputDecoration('Описание (необязательно)',
                    icon: Icons.message_outlined),
                style: AppStyles.bodyLarge,
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: category,
                decoration: AppStyles.inputDecoration('Категория',
                    icon: Icons.category_outlined),
                items: Note.categories.entries.map((e) =>
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
                ).toList(),
                onChanged: (v) => setDialogState(() => category = v ?? 'general'),
              ),
            ],
          )),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppStyles.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                final auth = context.read<AuthProvider>();
                await context.read<AppProvider>().addNote(
                  auth.userLogin,
                  titleCtrl.text.trim(),
                  msgCtrl.text.trim(),
                  category,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final auth = context.watch<AuthProvider>();
    final notes = provider.notes;

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
        title: Text(
          auth.isAdmin ? 'Заметки мойщиков' : 'Мои заметки',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
            tooltip: 'Обновить',
          ),
          if (auth.isAdmin && notes.any((n) => !n.isRead))
            IconButton(
              icon: const Icon(Icons.done_all_rounded, color: AppStyles.primary),
              onPressed: () => provider.markAllNotesRead(),
              tooltip: 'Прочитать все',
            ),
        ],
      ),
      floatingActionButton: auth.isWasher
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Новая заметка'),
              backgroundColor: AppStyles.primary,
              foregroundColor: Colors.white,
              onPressed: _showAddDialog,
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppStyles.primary))
          : notes.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.note_alt_outlined,
                  size: 56, color: AppStyles.textSecondary),
              const SizedBox(height: 12),
              Text(auth.isWasher ? 'Нет заметок. Нажмите + чтобы добавить' : 'Заметок пока нет',
                  style: const TextStyle(color: AppStyles.textSecondary,
                      fontSize: 16, fontWeight: FontWeight.w500)),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              itemCount: notes.length,
              itemBuilder: (_, i) => _NoteCard(
                note: notes[i],
                isAdmin: auth.isAdmin,
                displayName: _displayName(notes[i].username),
                onRead: () => provider.markNoteRead(notes[i].id!),
                onDelete: auth.isAdmin
                    ? () => provider.deleteNote(notes[i].id!)
                    : null,
              ),
            ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final Note note;
  final bool isAdmin;
  final String displayName;
  final VoidCallback onRead;
  final VoidCallback? onDelete;

  const _NoteCard({
    required this.note,
    required this.isAdmin,
    required this.displayName,
    required this.onRead,
    this.onDelete,
  });

  Color get _categoryColor {
    switch (note.category) {
      case 'urgent': return AppStyles.danger;
      case 'supply': return AppStyles.warning;
      case 'equipment': return AppStyles.primary;
      default: return AppStyles.textSecondary;
    }
  }

  IconData get _categoryIcon {
    switch (note.category) {
      case 'urgent': return Icons.warning_amber_rounded;
      case 'supply': return Icons.inventory_2_outlined;
      case 'equipment': return Icons.build_outlined;
      default: return Icons.note_alt_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: note.isRead ? AppStyles.border : color.withOpacity(0.4),
          width: note.isRead ? 1 : 1.5,
        ),
      ),
      child: InkWell(
        onTap: !note.isRead && isAdmin ? onRead : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_categoryIcon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppStyles.primaryBg,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(displayName,
                        style: const TextStyle(color: AppStyles.primary,
                            fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(note.categoryLabel,
                        style: TextStyle(color: color,
                            fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
                  if (!note.isRead) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: AppStyles.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    DateFormat('d MMM, HH:mm', 'ru').format(note.createdAt),
                    style: AppStyles.bodySmall,
                  ),
                ]),
                const SizedBox(height: 5),
                Text(note.title, style: const TextStyle(
                    color: AppStyles.textPrimary, fontSize: 14,
                    fontWeight: FontWeight.w600)),
                if (note.message.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(note.message, style: AppStyles.bodySmall,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ],
            )),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18,
                    color: AppStyles.textSecondary),
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ]),
        ),
      ),
    );
  }
}