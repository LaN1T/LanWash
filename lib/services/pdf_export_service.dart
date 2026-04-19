import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:file_saver/file_saver.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

class PdfExportService {
  static Future<Uint8List> createPdfBytes(String title, List<String> headers, List<List<String>> data) async {
    final pdf = pw.Document();
    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    final logoImage = pw.MemoryImage(
      (await rootBundle.load('assets/icon/icon.png')).buffer.asUint8List(),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 20),
            child: pw.Text('Страница ${context.pageNumber} из ${context.pagesCount}', style: const pw.TextStyle(fontSize: 10)),
          );
        },
        build: (pw.Context context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('LanWash - Система управления автомойкой', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  pw.Text('Официальный отчет', style: const pw.TextStyle(fontSize: 10)),
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
            pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text('Дата формирования: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              context: context,
              headers: headers,
              data: data,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
              cellStyle: const pw.TextStyle(fontSize: 12),
              cellAlignment: pw.Alignment.centerLeft,
              border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
              oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            ),
          ];
        },
      ),
    );
    return pdf.save();
  }

  static Future<void> showExportDialog(BuildContext context, {
    required String title,
    required String fileName,
    required Uint8List pdfBytes,
  }) async {
    final isMobile = Platform.isIOS || Platform.isAndroid;
    showDialog(
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
                  await Printing.sharePdf(bytes: pdfBytes, filename: '$fileName.pdf');
                } else {
                  String? outputFile = await FilePicker.platform.saveFile(
                    dialogTitle: 'Сохранить отчёт как...',
                    fileName: '$fileName.pdf',
                    type: FileType.custom,
                    allowedExtensions: ['pdf'],
                  );
                  if (outputFile != null) {
                    await File(outputFile).writeAsBytes(pdfBytes);
                  }
                }
              } catch (e) {
                print("Ошибка сохранения: $e");
              }
            },
            child: const Text('Скачать'),
          ),
          if (!isMobile)
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await Printing.sharePdf(bytes: pdfBytes, filename: '$fileName.pdf');
              },
              child: const Text('Поделиться'),
            ),
        ],
      ),
    );
  }
}
