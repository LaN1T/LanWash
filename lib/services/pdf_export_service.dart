import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';

class PdfExportService {
  static Future<void> generateReport({
    required String title,
    required List<String> headers,
    required List<List<String>> data,
  }) async {
    final pdf = pw.Document();

    // Используем шрифты из пакета printing для гарантированной поддержки кириллицы
    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                context: context,
                headers: headers,
                data: data,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                cellAlignment: pw.Alignment.centerLeft,
                border: pw.TableBorder.all(),
              ),
            ],
          );
        },
      ),
    );

    // Сохраняем в документы для надежности на Desktop
    final directory = await getApplicationDocumentsDirectory();
    final file = File("${directory.path}/report.pdf");
    
    // Используем Printing для шаринга/песочницы
    await Printing.sharePdf(
      bytes: await pdf.save(), 
      filename: 'report.pdf'
    );
  }
}
