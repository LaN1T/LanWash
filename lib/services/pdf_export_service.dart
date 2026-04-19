import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:file_saver/file_saver.dart';
import 'package:path_provider/path_provider.dart';

class PdfExportService {
  static Future<Uint8List> _createPdf(String title, List<String> headers, List<List<String>> data) async {
    final pdf = pw.Document();
    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

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
                pw.Container(
                  width: 45, height: 45,
                  decoration: const pw.BoxDecoration(color: PdfColors.blue800, shape: pw.BoxShape.circle),
                  child: pw.Center(child: pw.Text('LW', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 16))),
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
    required List<String> headers,
    required List<List<String>> data,
  }) async {
    final pdfBytes = await _createPdf(title, headers, data);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Экспорт отчета'),
        content: const Text('Выберите действие:'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                print("PDF: Попытка сохранения через saveAs");
                final path = await FileSaver.instance.saveAs(
                  name: fileName,
                  bytes: pdfBytes,
                  fileExtension: 'pdf',
                  mimeType: MimeType.pdf,
                );
                print("PDF: Файл сохранен по пути: $path");
              } catch (e) {
                print("PDF: Ошибка при сохранении: $e");
              }
            },
            child: const Text('Скачать'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Используем нативный Printing для шаринга - это безопасный путь для Sandbox
              await Printing.sharePdf(bytes: pdfBytes, filename: '$fileName.pdf');
            },
            child: const Text('Поделиться'),
          ),
        ],
      ),
    );
  }
}
