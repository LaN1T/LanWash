import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_styles.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class ReviewCreateScreen extends StatefulWidget {
  final String appointmentId;
  const ReviewCreateScreen({super.key, required this.appointmentId});

  @override
  State<ReviewCreateScreen> createState() => _ReviewCreateScreenState();
}

class _ReviewCreateScreenState extends State<ReviewCreateScreen> {
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) return;

    final auth = context.read<AuthProvider>();
    final api = context.read<ApiService>();
    final user = auth.user;
    if (user?.id == null) {
      _showSnack('Ошибка: не удалось определить пользователя', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final ok = await api.createReview(
      userId: user!.id!,
      rating: _rating,
      comment: _commentController.text.trim(),
      appointmentId: widget.appointmentId,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (ok) {
      _showSnack('Отзыв отправлен на модерацию');
      if (mounted) {
        Navigator.pop(context, true);
      }
    } else {
      _showSnack('Не удалось отправить отзыв', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppStyles.danger : AppStyles.success,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: theme.dividerColor),
        ),
        title: const Text('Оцените мойку',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Как прошла мойка?',
              style: AppStyles.adaptiveHeadingMedium(context),
            ),
            const SizedBox(height: 16),
            Semantics(
              label: 'Выбрано $_rating из 5 звезд',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final filled = index < _rating;
                  return Semantics(
                    button: true,
                    label: 'Оценить на ${index + 1} звезд',
                    child: GestureDetector(
                      onTap: () => setState(() => _rating = index + 1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          filled
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          size: 40,
                          color: filled
                              ? AppStyles.gold
                              : AppStyles.adaptiveBorder(context),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Комментарий',
              style: AppStyles.adaptiveLabel(context),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              maxLines: 5,
              maxLength: 2000,
              enabled: !_isLoading,
              decoration: AppStyles.inputDecorationFor(context, ''),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _rating > 0 && !_isLoading ? _submit : null,
                style: AppStyles.primaryButton,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Отправить отзыв'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
