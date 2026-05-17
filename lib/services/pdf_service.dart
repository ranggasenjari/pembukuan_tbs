import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/nota_model.dart';
import '../models/bon_model.dart';

final dateFmt = DateFormat('dd/MM/yyyy');
final timeFmt = DateFormat('HH:mm');

class PdfService {
  Future<Uint8List> generateNota(NotaModel nota, List<BonModel> bons) async {
    final pdf = pw.Document();

    // Simple basic layout
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          final totalBiayaBongkar = bons.fold(
            0.0,
            (sum, bon) => sum + (bon.biayaBongkar * bon.netto1),
          );
          final totalBpColt = bons.fold(0.0, (sum, bon) => sum + bon.bpColt);
          final totalPph = bons.fold(0.0, (sum, bon) => sum + bon.pph);
          final totalUangMinum = bons.fold(
            0.0,
            (sum, bon) => sum + bon.uangMinum,
          );
          final totalDp = bons.fold(0.0, (sum, bon) => sum + bon.dp);
          final totalDynamicDeductions = bons.fold(
            0.0,
            (sum, bon) =>
                sum + bon.deductions.fold(0.0, (dSum, d) => dSum + d.amount),
          );
          final totalPotongan =
              totalBiayaBongkar +
              totalBpColt +
              totalPph +
              totalUangMinum +
              totalDp +
              totalDynamicDeductions;
          final currencyFormatter = NumberFormat.currency(
            locale: 'id_ID',
            symbol: 'Rp ',
            decimalDigits: 0,
          );

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'NOTA TIMBANGAN',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(nota.notaNumber, style: pw.TextStyle(fontSize: 14)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('To:'),
                      pw.Text(nota.recipientName ?? '-'),
                      if (nota.recipientAddress != null &&
                          nota.recipientAddress!.isNotEmpty)
                        pw.Text(nota.recipientAddress!),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Date: ${dateFmt.format(nota.createdAt)} ${timeFmt.format(nota.createdAt)}',
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 40),
              pw.Table.fromTextArray(
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellAlignment: pw.Alignment.centerLeft,
                headers: [
                  'Date',
                  'Ticket No',
                  'Plate No',
                  'Driver',
                  'Netto',
                  'Harga',
                  'Total',
                ],
                data: bons
                    .map(
                      (bon) => [
                        DateFormat('dd/MM/yyyy').format(bon.bonDate),
                        bon.ticketNumber ?? '-',
                        bon.plateNumber,
                        bon.driverName ?? '-',
                        '${bon.netto2.toInt()} kg',
                        currencyFormatter.format(bon.price),
                        currencyFormatter.format(bon.price * bon.netto2),
                      ],
                    )
                    .toList(),
              ),
              pw.SizedBox(height: 20),

              // Deduction Details
              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Rincian Potongan:',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Table(
                      columnWidths: {
                        0: const pw.FixedColumnWidth(290),
                        1: const pw.FixedColumnWidth(60),
                      },
                      children: [
                        _buildPotonganRow(
                          'Biaya Bongkar',
                          totalBiayaBongkar,
                          currencyFormatter,
                        ),
                        _buildPotonganRow(
                          'BP/Colt',
                          totalBpColt,
                          currencyFormatter,
                        ),
                        _buildPotonganRow(
                          'PPh (0.25%)',
                          totalPph,
                          currencyFormatter,
                        ),
                        _buildPotonganRow(
                          'Uang Minum',
                          totalUangMinum,
                          currencyFormatter,
                        ),
                        _buildPotonganRow(
                          'DP / Panjar',
                          totalDp,
                          currencyFormatter,
                        ),
                        // Aggregated dynamic deductions
                        ...(() {
                          final Map<String, int> aggregated = {};
                          for (var bon in bons) {
                            for (var d in bon.deductions) {
                              aggregated[d.label] =
                                  (aggregated[d.label] ?? 0) + d.amount;
                            }
                          }
                          return aggregated.entries.map(
                            (e) => _buildPotonganRow(
                              e.key,
                              e.value.toDouble(),
                              currencyFormatter,
                            ),
                          );
                        })(),
                      ],
                    ),
                    pw.Divider(),
                    pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Total Potongan: ',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                        pw.SizedBox(width: 20),
                        pw.Text(
                          currencyFormatter.format(totalPotongan),
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 10),
              pw.Divider(thickness: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(
                    'TOTAL NOTA: ',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Text(
                    currencyFormatter.format(nota.totalAmount),
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.TableRow _buildPotonganRow(
    String label,
    double value,
    NumberFormat formatter,
  ) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 1),
          child: pw.Text(
            '$label :',
            textAlign: pw.TextAlign.right,
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 1),
          child: pw.Text(
            formatter.format(value),
            textAlign: pw.TextAlign.right,
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
      ],
    );
  }

  Future<void> printNota(NotaModel nota, List<BonModel> bons) async {
    final pdfBytes = await generateNota(nota, bons);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: getNotaFilename(nota, bons).replaceAll('.pdf', ''),
    );
  }

  String getNotaFilename(NotaModel nota, List<BonModel> bons) {
    final now = DateTime.now();
    final dayName = _getDayName(now);
    final timeStr = DateFormat('HH_mm').format(now);
    final recipient = (nota.recipientName ?? 'TanpaNama').replaceAll(' ', '_');
    final totalNetto2 = bons.fold(0.0, (sum, b) => sum + b.netto2).toInt();

    return 'Nota-${dayName}-${timeStr}-${recipient}-${totalNetto2}Kg.pdf';
  }

  String getNotaShareCaption(NotaModel nota, List<BonModel> bons) {
    final totalNetto2 = bons.fold(0.0, (sum, b) => sum + b.netto2).toInt();
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return '*NOTA TIMBANGAN*\n'
        'No: ${nota.notaNumber}\n'
        'Kepada: ${nota.recipientName ?? "-"}\n'
        '${_getDayName(DateTime.now())}, ${DateFormat('dd MMMM yyyy').format(DateTime.now())}\n'
        '--------------------------\n'
        'Netto: $totalNetto2 Kg\n'
        'Total: ${currencyFormatter.format(nota.totalAmount)}';
  }

  String _getDayName(DateTime date) {
    const days = {
      DateTime.monday: 'Senin',
      DateTime.tuesday: 'Selasa',
      DateTime.wednesday: 'Rabu',
      DateTime.thursday: 'Kamis',
      DateTime.friday: 'Jumat',
      DateTime.saturday: 'Sabtu',
      DateTime.sunday: 'Minggu',
    };
    return days[date.weekday] ?? '';
  }

  Future<Uint8List> generateThermalNota(NotaModel nota, BonModel bon) async {
    final pdf = pw.Document();
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: '',
      decimalDigits: 0,
    );

    final subtotal = bon.netto2 * bon.price;
    final spsiResult = bon.netto1 * bon.biayaBongkar;

    final pphPercent = (bon.pph / subtotal * 100);
    final pphDisplay = pphPercent > 0 ? pphPercent.toStringAsFixed(2) : "0.25";

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll57,
        margin: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'NOTA TIMBANGAN',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    pw.Text(
                      'No. ${nota.notaNumber}',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.normal,
                        fontSize: 6,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Divider(thickness: 1),
                  ],
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Table(
                columnWidths: {
                  0: const pw.FixedColumnWidth(40),
                  1: const pw.FixedColumnWidth(80),
                },
                children: [
                  pw.TableRow(
                    children: [
                      pw.Text('Kepada', style: const pw.TextStyle(fontSize: 8)),
                      pw.Text(
                        ': ${nota.recipientName ?? '-'}',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Text(
                        'Tanggal',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                      pw.Text(
                        ': ${dateFmt.format(nota.createdAt)} ${timeFmt.format(nota.createdAt)}',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 5),
              pw.Text(
                'Subtotal:',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 4),
                child: pw.Table(
                  columnWidths: {
                    0: const pw.FixedColumnWidth(65),
                    1: const pw.FixedColumnWidth(55),
                  },
                  children: [
                    pw.TableRow(
                      children: [
                        pw.Text(
                          '${bon.netto2.toInt()} Kg x Rp ${currencyFormatter.format(bon.price)}',
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                        pw.Text(
                          'Rp ${currencyFormatter.format(subtotal)}',
                          textAlign: pw.TextAlign.right,
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Potongan:',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 4),
                child: pw.Table(
                  columnWidths: {
                    0: const pw.FixedColumnWidth(65),
                    1: const pw.FixedColumnWidth(55),
                  },
                  children: [
                    pw.TableRow(
                      children: [
                        pw.Text(
                          'PPh ($pphDisplay%)',
                          style: const pw.TextStyle(fontSize: 7.5),
                        ),
                        pw.Text(
                          '${currencyFormatter.format(bon.pph)}',
                          textAlign: pw.TextAlign.right,
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Text(
                          'SPSI (${bon.netto1.toInt()} Kg x Rp ${currencyFormatter.format(bon.biayaBongkar)})',
                          style: const pw.TextStyle(fontSize: 7),
                        ),
                        pw.Text(
                          '${currencyFormatter.format(spsiResult)}',
                          textAlign: pw.TextAlign.right,
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Text('BP', style: const pw.TextStyle(fontSize: 8)),
                        pw.Text(
                          '${currencyFormatter.format(bon.bpColt)}',
                          textAlign: pw.TextAlign.right,
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Text(
                          'Uang minum',
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                        pw.Text(
                          '${currencyFormatter.format(bon.uangMinum)}',
                          textAlign: pw.TextAlign.right,
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Text(
                          'DP / Panjar',
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                        pw.Text(
                          '${currencyFormatter.format(bon.dp)}',
                          textAlign: pw.TextAlign.right,
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      ],
                    ),
                    ...bon.deductions.map(
                      (d) => pw.TableRow(
                        children: [
                          pw.Text(
                            d.label,
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                          pw.Text(
                            '${currencyFormatter.format(d.amount)}',
                            textAlign: pw.TextAlign.right,
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                  pw.Text(
                    'Rp ${currencyFormatter.format(nota.totalAmount)}',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 15),
              pw.Center(
                child: pw.Text(
                  'TERIMA KASIH',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  Future<void> printThermalNota(NotaModel nota, BonModel bon) async {
    final pdfBytes = await generateThermalNota(nota, bon);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Nota_Thermal_${nota.notaNumber}',
    );
  }
}
