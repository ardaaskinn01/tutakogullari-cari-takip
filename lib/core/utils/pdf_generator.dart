import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/mtul_calculation.dart';
import '../../models/glass_calculation.dart';
import 'helpers.dart';

class PdfGenerator {
  // --- Metretül ---

  static Future<Uint8List> createMtulPdfBytes(
    String customerName,
    List<MtulCalculation> calculations,
  ) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(
          base: font,
          bold: boldFont,
        ),
        build: (pw.Context context) {
          return [
            _buildHeader(customerName, 'Metretül Hesaplama Dökümü', font, boldFont),
            pw.SizedBox(height: 20),
            
            ...calculations.map((calc) {
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 24),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Calculation Header
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey200,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            Helpers.formatDateTime(calc.createdAt),
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(
                            Helpers.formatCurrency(calc.totalPrice),
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.green700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    
                    // Items Table
                    if (calc.items != null && calc.items!.isNotEmpty)
                      pw.Table(
                        border: pw.TableBorder.all(color: PdfColors.grey300),
                        children: [
                          // Table Header
                          pw.TableRow(
                            decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                            children: [
                              _buildTableCell('Parça Adı', isHeader: true),
                              _buildTableCell('Miktar', isHeader: true),
                              _buildTableCell('Birim Fiyat', isHeader: true),
                              _buildTableCell('Tutar', isHeader: true),
                            ],
                          ),
                          // Table Rows
                          ...calc.items!.map((item) => pw.TableRow(
                            children: [
                              _buildTableCell(item.componentName),
                              _buildTableCell(item.quantity.toString()),
                              _buildTableCell(Helpers.formatCurrency(item.unitPrice)),
                              _buildTableCell(
                                Helpers.formatCurrency(item.totalPrice),
                                alignRight: true,
                              ),
                            ],
                          )),
                        ],
                      ),
                  ],
                ),
              );
            }),
            
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text('TOPLAM GENEL TUTAR: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text(
                  Helpers.formatCurrency(calculations.fold(0, (sum, item) => sum + item.totalPrice)),
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static Future<void> generateMtulPdf(
    String customerName,
    List<MtulCalculation> calculations,
  ) async {
    final bytes = await createMtulPdfBytes(customerName, calculations);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: '${customerName}_mtul_dokumu.pdf',
    );
  }

  static Future<void> shareMtulPdf(
    String customerName,
    List<MtulCalculation> calculations,
  ) async {
    final bytes = await createMtulPdfBytes(customerName, calculations);
    await Printing.sharePdf(
      bytes: bytes,
      filename: '${customerName}_mtul_dokumu.pdf',
    );
  }

  // --- Cam m² ---

  static Future<Uint8List> createGlassPdfBytes(
    String customerName,
    List<GlassCalculation> calculations,
  ) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(
          base: font,
          bold: boldFont,
        ),
        build: (pw.Context context) {
          return [
            _buildHeader(customerName, 'Cam m² Hesaplama Dökümü', font, boldFont),
            pw.SizedBox(height: 20),
            
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(2), // Tarih
                1: const pw.FlexColumnWidth(2), // Ebat
                2: const pw.FlexColumnWidth(1), // Adet
                3: const pw.FlexColumnWidth(1.5), // Toplam m2
                4: const pw.FlexColumnWidth(1.5), // Fiyat
                5: const pw.FlexColumnWidth(1.5), // Tutar
              },
              children: [
                // Header
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    _buildTableCell('Tarih', isHeader: true),
                    _buildTableCell('Ebat (Boy x En)', isHeader: true),
                    _buildTableCell('Adet', isHeader: true),
                    _buildTableCell('Toplam m²', isHeader: true),
                    _buildTableCell('m² Fiyatı', isHeader: true),
                    _buildTableCell('Tutar', isHeader: true),
                  ],
                ),
                // Rows
                ...calculations.map((calc) => pw.TableRow(
                  children: [
                    _buildTableCell(Helpers.formatDateTime(calc.createdAt)),
                    _buildTableCell('${calc.height} x ${calc.width}'),
                    _buildTableCell(calc.quantity.toString()),
                    _buildTableCell('${calc.totalM2.toStringAsFixed(2)} m²'),
                    _buildTableCell(Helpers.formatCurrency(calc.unitPrice)),
                    _buildTableCell(Helpers.formatCurrency(calc.totalPrice), alignRight: true),
                  ],
                )),
              ],
            ),
            
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text('TOPLAM GENEL TUTAR: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text(
                  Helpers.formatCurrency(calculations.fold(0, (sum, item) => sum + item.totalPrice)),
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static Future<void> generateGlassPdf(
    String customerName,
    List<GlassCalculation> calculations,
  ) async {
    final bytes = await createGlassPdfBytes(customerName, calculations);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: '${customerName}_cam_dokumu.pdf',
    );
  }

  static Future<void> shareGlassPdf(
    String customerName,
    List<GlassCalculation> calculations,
  ) async {
    final bytes = await createGlassPdfBytes(customerName, calculations);
    await Printing.sharePdf(
      bytes: bytes,
      filename: '${customerName}_cam_dokumu.pdf',
    );
  }

  // --- Yardımcılar ---

  static pw.Widget _buildHeader(String customer, String title, pw.Font font, pw.Font boldFont) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Hest Yapı Pen',
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 20,
                color: PdfColors.blue800,
              ),
            ),
            pw.Text(
              Helpers.formatDate(DateTime.now()),
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
            ),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Text(
          title,
          style: pw.TextStyle(font: boldFont, fontSize: 18),
        ),
        pw.Text(
          'Müşteri: $customer',
          style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
        ),
        pw.Divider(color: PdfColors.grey400),
      ],
    );
  }

  static pw.Widget _buildTableCell(String text, {bool isHeader = false, bool alignRight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: 10,
        ),
      ),
    );
  }
}
