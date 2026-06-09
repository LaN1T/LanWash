import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../app_styles.dart';
import '../shared/appointment_detail_widget.dart';

class QrScannerBody extends StatefulWidget {
  const QrScannerBody({super.key});

  @override
  State<QrScannerBody> createState() => _QrScannerWebBodyState();
}

class _QrScannerWebBodyState extends State<QrScannerBody> {
  final _controller = TextEditingController();
  bool _isLoading = false;

  Future<void> _onSearch() async {
    final code = _controller.text.trim();
    if (code.isEmpty || _isLoading) return;
    setState(() => _isLoading = true);

    try {
      final apiService = ApiService();
      final appointment = await apiService.scanQrCode(code);

      if (!mounted) return;

      if (appointment == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Запись не найдена или недоступна'),
            backgroundColor: AppStyles.danger,
          ),
        );
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AppointmentDetailWidget(appointment: appointment, isClient: false),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppStyles.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.qr_code_scanner,
                size: 80,
                color: AppStyles.adaptiveTextSecondary(context).withValues(alpha: 0.4),
              ),
              const SizedBox(height: 24),
              Text(
                'Сканер QR недоступен в браузере',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppStyles.adaptiveTextPrimary(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Введите ID записи вручную',
                style: TextStyle(
                  fontSize: 14,
                  color: AppStyles.adaptiveTextSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _controller,
                enabled: !_isLoading,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _onSearch(),
                decoration: InputDecoration(
                  hintText: 'ID записи',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppStyles.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _onSearch,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Найти'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
