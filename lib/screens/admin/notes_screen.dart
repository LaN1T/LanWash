import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../app_styles.dart';
import '../../models/note.dart';
import '../../models/user.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/note_provider.dart';

class NotesScreen extends StatefulWidget {
  final bool isEmbedded;
  const NotesScreen({super.key, this.isEmbedded = false});
  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  bool _loading = true;
  List<User> _washers = [];

  String _displayName(String username) {
    final w = _washers.where((w) => w.username == username);
    if (w.isNotEmpty) {
      return w.first.displayName.isNotEmpty
          ? w.first.displayName
          : w.first.username;
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
    final noteProvider = context.read<NoteProvider>();
    final appointmentProvider = context.read<AppointmentProvider>();
    if (auth.isAdmin) {
      await noteProvider.loadNotes();
      _washers = await appointmentProvider.getWashers();
    } else {
      await noteProvider.loadNotes(username: auth.userLogin);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _showAddDialog() {
    final titleCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    String category = 'general';

    showDialog(
      context: context,
      builder: (ctx) => Theme(
        data: Theme.of(context).copyWith(
          scrollbarTheme: ScrollbarThemeData(
            thickness: WidgetStateProperty.all(0),
          ),
        ),
        child: StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: AppStyles.adaptiveCard(context),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Новая заметка'),
            content: SizedBox(
              width: 300,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: AppStyles.inputDecorationFor(
                        context,
                        'Заголовок',
                        icon: Icons.title_rounded,
                      ),
                      style: AppStyles.bodyLarge,
                      minLines: 1,
                      maxLines: 3, // Теперь заголовок может быть до 3 строк
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: msgCtrl,
                      decoration: AppStyles.inputDecorationFor(
                        context,
                        'Описание (необязательно)',
                        icon: Icons.message_outlined,
                      ),
                      style: AppStyles.bodyLarge,
                      minLines: 3,
                      maxLines: 5,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: AppStyles.inputDecorationFor(
                        context,
                        'Категория',
                        icon: Icons.category_outlined,
                      ),
                      items: Note.categories.entries
                          .map((e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => category = v ?? 'general'),
                    ),
                  ],
                ),
              ),
            ),
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
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () async {
                  if (titleCtrl.text.trim().isEmpty) return;
                  final auth = context.read<AuthProvider>();
                  await context.read<NoteProvider>().addNote(
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final noteProvider = context.watch<NoteProvider>();
    final auth = context.watch<AuthProvider>();
    final notes = noteProvider.notes;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(
                    height: 1, color: AppStyles.adaptiveBorder(context)),
              ),
              title: Text(
                auth.isAdmin ? 'Заметки мойщиков' : 'Мои заметки',
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _load,
                  tooltip: 'Обновить',
                ),
                if (auth.isAdmin && notes.any((n) => !n.isRead))
                  IconButton(
                    icon: const Icon(Icons.done_all_rounded,
                        color: AppStyles.primary),
                    onPressed: () => noteProvider.markAllNotesRead(),
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
          ? const Center(
              child: CircularProgressIndicator(color: AppStyles.primary))
          : notes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.note_alt_outlined,
                        size: 56,
                        color: AppStyles.adaptiveTextSecondary(context),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        auth.isWasher
                            ? 'Нет заметок. Нажмите + чтобы добавить'
                            : 'Заметок пока нет',
                        style: TextStyle(
                          color: AppStyles.adaptiveTextSecondary(context),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                  itemCount: notes.length,
                  itemBuilder: (_, i) => _NoteCard(
                    note: notes[i],
                    isAdmin: auth.isAdmin,
                    displayName: _displayName(notes[i].username),
                    onRead: () => noteProvider.markNoteRead(notes[i].id!),
                    onDelete: auth.isAdmin
                        ? () => noteProvider.deleteNote(notes[i].id!)
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

  Color _categoryColor(BuildContext context) {
    switch (note.category) {
      case 'urgent':
        return AppStyles.danger;
      case 'supply':
        return AppStyles.warning;
      case 'equipment':
        return AppStyles.primary;
      default:
        return AppStyles.adaptiveTextSecondary(context);
    }
  }

  IconData get _categoryIcon {
    switch (note.category) {
      case 'urgent':
        return Icons.warning_amber_rounded;
      case 'supply':
        return Icons.inventory_2_outlined;
      case 'equipment':
        return Icons.build_outlined;
      default:
        return Icons.note_alt_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppStyles.adaptiveCard(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: note.isRead
              ? AppStyles.adaptiveBorder(context)
              : color.withValues(alpha: 0.4),
          width: note.isRead ? 1 : 1.5,
        ),
      ),
      child: InkWell(
        onTap: !note.isRead && isAdmin ? onRead : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_categoryIcon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppStyles.adaptivePrimaryBg(context),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            displayName,
                            style: const TextStyle(
                              color: AppStyles.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            note.categoryLabel,
                            style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (!note.isRead) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppStyles.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                        const Spacer(),
                        Text(
                          DateFormat('d MMM, HH:mm', 'ru')
                              .format(note.createdAt),
                          style: AppStyles.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      note.title,
                      style: TextStyle(
                        color: AppStyles.adaptiveTextPrimary(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (note.message.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        note.message,
                        style: AppStyles.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: AppStyles.adaptiveTextSecondary(context),
                  ),
                  onPressed: onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
