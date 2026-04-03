import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_styles.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../profile_screen.dart';
import '../notes_screen.dart';

class WasherShell extends StatefulWidget {
  const WasherShell({super.key});
  @override State<WasherShell> createState() => _WasherShellState();
}

class _WasherShellState extends State<WasherShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      context.read<AppProvider>().loadNotes(username: auth.userLogin);
    });
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
          const Text('Мои заметки', style: TextStyle(
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
      body: const NotesScreen(),
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
              leading: const Icon(Icons.note_alt_rounded,
                  color: AppStyles.primary, size: 22),
              title: const Text('Мои заметки',
                  style: TextStyle(color: AppStyles.primary,
                      fontWeight: FontWeight.w600)),
              selected: true,
              selectedTileColor: AppStyles.primary.withOpacity(0.08),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              onTap: () => Navigator.pop(ctx),
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
