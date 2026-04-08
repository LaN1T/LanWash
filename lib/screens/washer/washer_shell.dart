import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../app_styles.dart';
import '../../models/appointment.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../profile_screen.dart';
import '../notes_screen.dart';

class WasherShell extends StatefulWidget {
  const WasherShell({super.key});
  @override State<WasherShell> createState() => _WasherShellState();
}

class _WasherShellState extends State<WasherShell> {
  int _tabIndex = 0;
  List<Appointment> _assignedAppointments = [];
  bool _loadingAppts = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      context.read<AppProvider>().loadNotes(username: auth.userLogin);
      _loadAssignedAppointments();
    });
  }

  Future<void> _loadAssignedAppointments() async {
    final auth = context.read<AuthProvider>();
    final provider = context.read<AppProvider>();
    final appts = await provider.getAppointmentsByWasher(auth.userLogin);
    if (mounted) {
      setState(() {
        _assignedAppointments = appts;
        _loadingAppts = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

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
        title: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppStyles.primaryGradient,
            ),
            child: const Icon(Icons.local_car_wash,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Text(_tabIndex == 0 ? 'Мои записи' : 'Мои заметки', style: const TextStyle(
              fontSize: 17, fontWeight: FontWeight.w700,
              color: AppStyles.textPrimary)),
          Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppStyles.warning.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Мойщик',
                style: TextStyle(color: AppStyles.warning, fontSize: 10,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
      drawer: _buildDrawer(context, auth),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          _buildAppointmentsTab(),
          const NotesScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppStyles.border)),
        ),
        child: NavigationBar(
          selectedIndex: _tabIndex,
          onDestinationSelected: (i) => setState(() => _tabIndex = i),
          backgroundColor: Colors.transparent,
          elevation: 0,
          indicatorColor: AppStyles.primaryBg,
          destinations: [
            NavigationDestination(
              icon: Badge(
                isLabelVisible: _assignedAppointments.isNotEmpty,
                label: Text('${_assignedAppointments.length}'),
                backgroundColor: AppStyles.primary,
                child: const Icon(Icons.calendar_today_outlined,
                    color: AppStyles.textSecondary),
              ),
              selectedIcon: const Icon(Icons.calendar_today, color: AppStyles.primary),
              label: 'Записи',
            ),
            const NavigationDestination(
              icon: Icon(Icons.note_alt_outlined, color: AppStyles.textSecondary),
              selectedIcon: Icon(Icons.note_alt, color: AppStyles.primary),
              label: 'Заметки',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentsTab() {
    if (_loadingAppts) {
      return const Center(child: CircularProgressIndicator(color: AppStyles.primary));
    }
    if (_assignedAppointments.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.event_available, size: 64, color: AppStyles.textMuted.withOpacity(0.5)),
          const SizedBox(height: 12),
          const Text('Нет назначенных записей',
              style: TextStyle(color: AppStyles.textSecondary, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Здесь будут записи, назначенные вам',
              style: TextStyle(color: AppStyles.textMuted, fontSize: 13)),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Обновить'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppStyles.primary,
              side: const BorderSide(color: AppStyles.primary),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              setState(() => _loadingAppts = true);
              _loadAssignedAppointments();
            },
          ),
        ]),
      );
    }

    return RefreshIndicator(
      color: AppStyles.primary,
      onRefresh: _loadAssignedAppointments,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _assignedAppointments.length,
        itemBuilder: (context, index) {
          final a = _assignedAppointments[index];
          return _WasherAppointmentCard(appointment: a);
        },
      ),
    );
  }

  Widget _buildDrawer(BuildContext ctx, AuthProvider auth) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Column(children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            color: Colors.white,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppStyles.primaryGradient,
                  boxShadow: [BoxShadow(
                    color: AppStyles.primary.withOpacity(0.25),
                    blurRadius: 16,
                  )],
                ),
                child: const Icon(Icons.local_car_wash,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(height: 14),
              const Text('LanWash', style: TextStyle(
                  color: AppStyles.textPrimary, fontSize: 20,
                  fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppStyles.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppStyles.warning.withOpacity(0.2)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.person_rounded,
                      size: 12, color: AppStyles.warning),
                  const SizedBox(width: 4),
                  Text(auth.username, style: const TextStyle(
                      color: AppStyles.warning, fontSize: 11,
                      fontWeight: FontWeight.w600)),
                ]),
              ),
            ]),
          ),
          const Divider(color: AppStyles.border, height: 1),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: ListTile(
              minLeadingWidth: 24,
              leading: Icon(
                _tabIndex == 0 ? Icons.calendar_today : Icons.calendar_today_outlined,
                color: _tabIndex == 0 ? AppStyles.primary : AppStyles.textSecondary, size: 22),
              title: Text('Мои записи',
                  style: TextStyle(
                    color: _tabIndex == 0 ? AppStyles.primary : AppStyles.textPrimary,
                    fontWeight: _tabIndex == 0 ? FontWeight.w600 : FontWeight.normal)),
              selected: _tabIndex == 0,
              selectedTileColor: AppStyles.primary.withOpacity(0.08),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              onTap: () {
                setState(() => _tabIndex = 0);
                Navigator.pop(ctx);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: ListTile(
              minLeadingWidth: 24,
              leading: Icon(
                _tabIndex == 1 ? Icons.note_alt_rounded : Icons.note_alt_outlined,
                color: _tabIndex == 1 ? AppStyles.primary : AppStyles.textSecondary, size: 22),
              title: Text('Мои заметки',
                  style: TextStyle(
                    color: _tabIndex == 1 ? AppStyles.primary : AppStyles.textPrimary,
                    fontWeight: _tabIndex == 1 ? FontWeight.w600 : FontWeight.normal)),
              selected: _tabIndex == 1,
              selectedTileColor: AppStyles.primary.withOpacity(0.08),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              onTap: () {
                setState(() => _tabIndex = 1);
                Navigator.pop(ctx);
              },
            ),
          ),
          const Divider(color: AppStyles.border, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: ListTile(
              minLeadingWidth: 24,
              leading: const Icon(Icons.person_outline_rounded,
                  color: AppStyles.textSecondary, size: 22),
              title: const Text('Профиль',
                  style: TextStyle(color: AppStyles.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(ctx, MaterialPageRoute(
                    builder: (_) => const ProfileScreen()));
              },
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: ListTile(
              minLeadingWidth: 24,
              leading: const Icon(Icons.logout_outlined,
                  color: AppStyles.textSecondary, size: 22),
              title: const Text('Выйти',
                  style: TextStyle(color: AppStyles.textSecondary)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmLogout(ctx);
              },
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ]),
      ),
    );
  }

  void _confirmLogout(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Выйти из аккаунта?'),
        content: const Text('Вы вернётесь на экран входа.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppStyles.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            onPressed: () {
              Navigator.pop(ctx);
              ctx.read<AuthProvider>().logout();
            },
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
  }
}

// ─── Карточка записи для мойщика (только просмотр) ───────────────────────────
class _WasherAppointmentCard extends StatelessWidget {
  final Appointment appointment;
  const _WasherAppointmentCard({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final statusColor = AppStyles.statusColor(a.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppStyles.border),
      ),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showDetail(context, a),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Статус + дата
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(AppStyles.statusIcon(a.status), size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(AppStyles.statusLabel(a.status),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                            color: statusColor)),
                  ]),
                ),
                const Spacer(),
                Text(DateFormat('d MMM, HH:mm', 'ru').format(a.dateTime),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                        color: AppStyles.textPrimary)),
              ]),
              const SizedBox(height: 10),
              // Клиент
              Row(children: [
                const Icon(Icons.person, size: 16, color: AppStyles.textSecondary),
                const SizedBox(width: 6),
                Expanded(child: Text(a.clientName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                        color: AppStyles.textPrimary))),
              ]),
              const SizedBox(height: 6),
              // Авто
              Row(children: [
                const Icon(Icons.directions_car, size: 16, color: AppStyles.textSecondary),
                const SizedBox(width: 6),
                Text(a.carModel,
                    style: const TextStyle(fontSize: 13, color: AppStyles.textSecondary)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppStyles.bgMuted,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(a.carNumber,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                          color: AppStyles.textPrimary)),
                ),
              ]),
              const SizedBox(height: 6),
              // Тип мойки + цена
              Row(children: [
                const Icon(Icons.local_car_wash, size: 16, color: AppStyles.textSecondary),
                const SizedBox(width: 6),
                Expanded(child: Text(a.washType.displayName,
                    style: const TextStyle(fontSize: 13, color: AppStyles.textSecondary))),
                Text('${a.totalPrice} \u20BD',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                        color: AppStyles.primary)),
              ]),
              // Доп. услуги
              if (a.additionalServices.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6, runSpacing: 4,
                  children: a.additionalServices.map((s) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppStyles.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(s, style: const TextStyle(fontSize: 11,
                        color: AppStyles.primary)),
                  )).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, Appointment a) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppStyles.border,
                borderRadius: BorderRadius.circular(2),
              ),
            )),
            Text('Детали записи', style: AppStyles.headingMedium),
            const SizedBox(height: 16),
            _detailRow(Icons.schedule, 'Статус', AppStyles.statusLabel(a.status)),
            _detailRow(Icons.calendar_today, 'Дата',
                DateFormat('d MMMM yyyy, HH:mm', 'ru').format(a.dateTime)),
            _detailRow(Icons.person, 'Клиент', a.clientName),
            _detailRow(Icons.directions_car, 'Авто', '${a.carModel} ${a.carNumber}'),
            _detailRow(Icons.local_car_wash, 'Мойка', a.washType.displayName),
            _detailRow(Icons.payments, 'Цена', '${a.totalPrice} \u20BD'),
            if (a.additionalServices.isNotEmpty)
              _detailRow(Icons.add_circle_outline, 'Доп. услуги',
                  a.additionalServices.join(', ')),
            if (a.notes.isNotEmpty)
              _detailRow(Icons.note, 'Заметка', a.notes),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: AppStyles.primary),
        const SizedBox(width: 10),
        SizedBox(
          width: 90,
          child: Text(label, style: AppStyles.bodyMedium),
        ),
        Expanded(child: Text(value,
            style: AppStyles.bodyLarge.copyWith(fontWeight: FontWeight.w500))),
      ]),
    );
  }
}
