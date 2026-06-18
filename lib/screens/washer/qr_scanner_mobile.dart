import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/api_service.dart';
import '../../app_styles.dart';
import '../shared/appointment_detail_widget.dart';
import 'package:lanwash/core/service_locator.dart';

class QrScannerBody extends StatefulWidget {
  const QrScannerBody({super.key});

  @override
  State<QrScannerBody> createState() => _QrScannerBodyState();
}

class _QrScannerBodyState extends State<QrScannerBody> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;

  Future<void> _processCode(String code) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    await _controller.stop();

    try {
      final apiService = sl<ApiService>();
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

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AppointmentDetailWidget(
              appointment: appointment, isClient: false),
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
        setState(() => _isProcessing = false);
      }
      await _controller.start();
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
        MobileScanner(
          controller: _controller,
          onDetect: (capture) {
            final barcodes = capture.barcodes;
            if (barcodes.isEmpty) return;
            final code = barcodes.first.rawValue;
            if (code == null || code.isEmpty) return;
            _processCode(code);
          },
          errorBuilder: (context, error, child) {
            final isPermission =
                error.errorCode == MobileScannerErrorCode.permissionDenied;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPermission
                          ? Icons.camera_alt_outlined
                          : Icons.error_outline,
                      size: 64,
                      color: AppStyles.adaptiveTextSecondary(context)
                          .withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isPermission
                          ? 'Доступ к камере запрещён'
                          : 'Ошибка камеры',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppStyles.adaptiveTextPrimary(context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isPermission
                          ? 'Пожалуйста, разрешите доступ к камере в настройках устройства, чтобы сканировать QR-коды.'
                          : 'Не удалось запустить камеру. Попробуйте перезапустить приложение.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppStyles.adaptiveTextSecondary(context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        if (_isProcessing)
          Container(
            color: Colors.black54,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }
}
