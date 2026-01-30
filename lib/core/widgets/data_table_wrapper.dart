import 'package:flutter/material.dart';

class DataTableWrapper extends StatelessWidget {
  final List<DataColumn> columns;
  final List<DataRow> rows;
  final String title;
  final List<Widget>? actions;

  const DataTableWrapper({
    super.key,
    required this.columns,
    required this.rows,
    required this.title,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 900;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (actions != null) Row(children: actions!),
              ],
            ),
            const SizedBox(height: 16),
            if (rows.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('Gösterilecek veri bulunamadı.'),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: isDesktop ? MediaQuery.of(context).size.width - 350 : 600,
                  ),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      Theme.of(context).primaryColor.withOpacity(0.05),
                    ),
                    columns: columns,
                    rows: rows,
                    columnSpacing: 24,
                    horizontalMargin: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
