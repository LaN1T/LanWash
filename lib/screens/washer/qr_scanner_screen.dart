import 'package:flutter/material.dart';
import 'qr_scanner_mobile.dart'
    if (dart.library.html) 'qr_scanner_web.dart';

class QrScannerScreen extends StatelessWidget {
  const QrScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сканировать QR'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const QrScannerBody(),
    );
  }
}
