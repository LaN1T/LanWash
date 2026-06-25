import 'package:flutter/material.dart';
import 'package:lanwash/widgets/admin/admin_card.dart';
import 'package:lanwash/widgets/admin/export_button.dart';

class ReportTableCard extends StatelessWidget {
  final String title;
  final List<DataColumn> columns;
  final List<DataRow> rows;
  final VoidCallback? onExportPdf;
  final VoidCallback? onExportExcel;

  const ReportTableCard({
    super.key,
    required this.title,
    required this.columns,
    required this.rows,
    this.onExportPdf,
    this.onExportExcel,
  });

  @override
  Widget build(BuildContext context) {
    final headerCells = columns
        .map((c) => DefaultTextStyle.merge(
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              child: c.label,
            ))
        .toList();

    final tableRows = [
      TableRow(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        children: headerCells
            .map((cell) => TableCell(
                  verticalAlignment: TableCellVerticalAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: cell,
                  ),
                ))
            .toList(),
      ),
      ...rows.map((row) {
        return TableRow(
          children: row.cells
              .map((cell) => TableCell(
                    verticalAlignment: TableCellVerticalAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: cell.child,
                    ),
                  ))
              .toList(),
        );
      }),
    ];

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              ExportButton(
                  onExportPdf: onExportPdf, onExportExcel: onExportExcel),
            ],
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            const Center(child: Text('Нет данных'))
          else
            Table(
              columnWidths: {
                for (var i = 0; i < columns.length; i++)
                  i: const FlexColumnWidth(1),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: tableRows,
            ),
        ],
      ),
    );
  }
}
