import 'package:flutter/material.dart';
import 'package:lanwash/app_styles.dart';

class ExportButton extends StatelessWidget {
  final VoidCallback? onExportPdf;
  final VoidCallback? onExportExcel;

  const ExportButton({
    super.key,
    this.onExportPdf,
    this.onExportExcel,
  });

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppStyles.adaptiveCard(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppStyles.adaptiveBorder(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Экспортировать',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            if (onExportExcel != null)
              ListTile(
                leading: Icon(Icons.table_chart, color: Colors.green.shade700),
                title: const Text('Excel (.xlsx)'),
                onTap: () {
                  Navigator.pop(context);
                  onExportExcel!();
                },
              ),
            if (onExportPdf != null)
              ListTile(
                leading: Icon(Icons.picture_as_pdf, color: Colors.red.shade700),
                title: const Text('PDF (.pdf)'),
                onTap: () {
                  Navigator.pop(context);
                  onExportPdf!();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _showOptions(context),
      icon: const Icon(Icons.download),
      label: const Text('Экспорт'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppStyles.adaptiveCard(context),
        foregroundColor: AppStyles.adaptiveTextPrimary(context),
        elevation: 0,
        side: BorderSide(color: AppStyles.adaptiveBorder(context)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    );
  }
}
