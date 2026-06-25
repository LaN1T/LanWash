import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:file_saver/file_saver.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' as io;
import 'package:lanwash/models/financial_report.dart';
import 'package:lanwash/models/washer_payroll_report.dart';
import 'package:lanwash/models/cancellations_report.dart';
import 'package:lanwash/models/promo_effectiveness_report.dart';

class PdfExportService {
  static Future<({pw.Font regular, pw.Font bold})> _loadFonts() async {
    final regularData =
        await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
    return (
      regular: pw.Font.ttf(regularData),
      bold: pw.Font.ttf(boldData),
    );
  }

  static Future<Uint8List> createPdfBytes(
      String title, List<String> headers, List<List<String>> data) async {
    final pdf = pw.Document();
    final fonts = await _loadFonts();

    final logoImage = pw.MemoryImage(
      (await rootBundle.load('assets/icon/app_icon.png')).buffer.asUint8List(),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold),
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 20),
            child: pw.Text(
                'Страница ${context.pageNumber} из ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 10)),
          );
        },
        build: (pw.Context context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('LanWash - Система управления автомойкой',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 14)),
                      pw.Text('Официальный отчет',
                          style: const pw.TextStyle(fontSize: 10)),
                    ]),
                pw.ClipOval(
                  child: pw.Container(
                    width: 45,
                    height: 45,
                    child: pw.Image(logoImage, fit: pw.BoxFit.cover),
                  ),
                ),
              ],
            ),
            pw.Divider(),
            pw.SizedBox(height: 20),
            pw.Text(title,
                style:
                    pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text(
                'Дата формирования: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              context: context,
              headers: headers,
              data: data,
              headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.blue800),
              cellStyle: const pw.TextStyle(fontSize: 12),
              cellAlignment: pw.Alignment.centerLeft,
              border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
              oddRowDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey100),
            ),
          ];
        },
      ),
    );
    return pdf.save();
  }

  static Future<void> showExportDialog(
    BuildContext context, {
    required String title,
    required String fileName,
    required Uint8List pdfBytes,
  }) async {
    final isMobile = defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Экспорт отчета'),
        content: const Text('Подтвердите действие:'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                if (isMobile) {
                  await Printing.sharePdf(
                      bytes: pdfBytes, filename: '$fileName.pdf');
                } else if (!kIsWeb) {
                  final outputFile = await FilePicker.platform.saveFile(
                    dialogTitle: 'Сохранить отчёт как...',
                    fileName: '$fileName.pdf',
                    type: FileType.custom,
                    allowedExtensions: ['pdf'],
                  );
                  if (outputFile != null) {
                    final file = io.File(outputFile);
                    await file.writeAsBytes(pdfBytes);
                  }
                } else if (kIsWeb) {
                  await FileSaver.instance.saveFile(
                    name: '$fileName.pdf',
                    bytes: pdfBytes,
                    mimeType: MimeType.pdf,
                  );
                } else {
                  await Printing.sharePdf(
                      bytes: pdfBytes, filename: '$fileName.pdf');
                }
              } catch (e) {
                if (kDebugMode) debugPrint('PDF export error: $e');
              }
            },
            child: const Text('Скачать'),
          ),
          if (!isMobile)
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await Printing.sharePdf(
                    bytes: pdfBytes, filename: '$fileName.pdf');
              },
              child: const Text('Поделиться'),
            ),
        ],
      ),
    );
  }

  static Future<void> exportFinancialReport(FinancialReport report) async {
    final pdf = pw.Document();
    final fonts = await _loadFonts();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold),
        header: (context) => _buildHeader('Финансовый отчёт'),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildSummaryRow([
            _Summary('Выручка',
                '${report.summary['revenue']?.toStringAsFixed(0)} ₽'),
            _Summary('Записей', '${report.summary['appointments_count']}'),
          ]),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            context: context,
            headers: ['Период', 'Записей', 'Услуги', 'Скидки', 'Выручка'],
            data: report.items
                .map((e) => [
                      e.period,
                      e.appointmentsCount.toString(),
                      '${e.servicesTotal.toStringAsFixed(0)} ₽',
                      '${e.discountsTotal.toStringAsFixed(0)} ₽',
                      '${e.revenue.toStringAsFixed(0)} ₽',
                    ])
                .toList(),
          ),
        ],
      ),
    );
    await _savePdf(pdf, 'financial_report');
  }

  static Future<void> exportWasherPayrollReport(
      WasherPayrollReport report) async {
    final pdf = pw.Document();
    final fonts = await _loadFonts();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold),
        header: (context) => _buildHeader('Зарплата мойщиков'),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            context: context,
            headers: ['Мойщик', 'Записей', 'Услуги', 'Чаевые', 'Итого'],
            data: report.items
                .map((e) => [
                      e.washerName,
                      e.appointmentsCount.toString(),
                      '${e.servicesTotal.toStringAsFixed(0)} ₽',
                      '${e.tipsTotal.toStringAsFixed(0)} ₽',
                      '${e.total.toStringAsFixed(0)} ₽',
                    ])
                .toList(),
          ),
        ],
      ),
    );
    await _savePdf(pdf, 'washer_payroll_report');
  }

  static Future<void> exportCancellationsReport(
      CancellationsReport report) async {
    final pdf = pw.Document();
    final fonts = await _loadFonts();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold),
        header: (context) => _buildHeader('Отмены и возвраты'),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildSummaryRow([
            _Summary('Отмен', '${report.summary['total_cancellations']}'),
            _Summary('Потеря',
                '${((report.summary['lost_revenue'] ?? 0) as num).toStringAsFixed(0)} ₽'),
          ]),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            context: context,
            headers: ['Дата', 'Клиент', 'Авто', 'Причина', 'Потеря'],
            data: report.items
                .map((e) => [
                      DateFormat('dd.MM.yyyy').format(e.date),
                      e.clientName,
                      e.carModel,
                      e.reason ?? '-',
                      '${e.lostRevenue.toStringAsFixed(0)} ₽',
                    ])
                .toList(),
          ),
        ],
      ),
    );
    await _savePdf(pdf, 'cancellations_report');
  }

  static Future<void> exportPromoEffectivenessReport(
      PromoEffectivenessReport report) async {
    final pdf = pw.Document();
    final fonts = await _loadFonts();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold),
        header: (context) => _buildHeader('Эффективность акций'),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            context: context,
            headers: ['Акция', 'Использований', 'Выручка', 'Скидка'],
            data: report.items
                .map((e) => [
                      e.promoName,
                      e.usesCount.toString(),
                      '${e.revenue.toStringAsFixed(0)} ₽',
                      '${e.discountTotal.toStringAsFixed(0)} ₽',
                    ])
                .toList(),
          ),
        ],
      ),
    );
    await _savePdf(pdf, 'promo_effectiveness_report');
  }

  static pw.Widget _buildHeader(String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('LanWash - Система управления автомойкой',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 14)),
                pw.Text('Официальный отчет',
                    style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ],
        ),
        pw.Divider(),
        pw.SizedBox(height: 8),
        pw.Text(title,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.Text(
            'Дата формирования: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 12),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 20),
      child: pw.Text('Страница ${context.pageNumber} из ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 10)),
    );
  }

  static pw.Widget _buildSummaryRow(List<_Summary> items) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.start,
      children: items
          .map((s) => pw.Container(
                margin: const pw.EdgeInsets.only(right: 24),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(s.label, style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(s.value,
                        style: pw.TextStyle(
                            fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ))
          .toList(),
    );
  }

  static Future<void> _savePdf(pw.Document pdf, String fileName) async {
    final bytes = await pdf.save();
    if (kIsWeb) {
      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        mimeType: MimeType.pdf,
      );
    } else {
      await Printing.sharePdf(bytes: bytes, filename: '$fileName.pdf');
    }
  }
}

class _Summary {
  final String label;
  final String value;

  _Summary(this.label, this.value);
}
