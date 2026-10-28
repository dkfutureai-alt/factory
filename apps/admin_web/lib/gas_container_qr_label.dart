import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Printable, self-contained FactoryOS asset identity label.
///
/// It does not fetch network resources or use private customer details. A QR
/// label identifies a registered asset but is NOT gas-pressure certification,
/// ownership proof, stock custody proof, or permission to dispatch/refill.
Future<Uint8List> buildGasContainerQrLabel({
  required String qrCode,
  required String serialNumber,
  required String containerType,
}) async {
  if (!RegExp(r'^FA-[A-F0-9]{32}$').hasMatch(qrCode)) {
    throw ArgumentError.value(qrCode, 'qrCode', 'Invalid asset QR token');
  }
  if (!RegExp(r'^[A-Z0-9][A-Z0-9._/-]{2,79}$').hasMatch(serialNumber)) {
    throw ArgumentError.value(serialNumber, 'serialNumber', 'Invalid normalized serial');
  }
  if (containerType != 'cylinder' && containerType != 'dura') {
    throw ArgumentError.value(containerType, 'containerType', 'Unsupported container type');
  }

  const mm = PdfPageFormat.mm;
  final pdf = pw.Document(compress: true);
  pdf.addPage(pw.Page(
    pageFormat: const PdfPageFormat(90 * mm, 55 * mm, marginAll: 0),
    build: (_) => pw.Container(
      padding: pw.EdgeInsets.all(3 * mm),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColors.black, width: 0.7),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: qrCode,
            width: 43 * mm,
            height: 43 * mm,
            drawText: false,
            color: PdfColors.black,
            backgroundColor: PdfColors.white,
          ),
          pw.SizedBox(width: 3 * mm),
          pw.Expanded(child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text('FACTORYOS', style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
              )),
              pw.Text(containerType.toUpperCase(),
                  style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 2 * mm),
              pw.Text(_wrapSerial(serialNumber),
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                maxLines: 5,
              ),
              pw.SizedBox(height: 2 * mm),
              pw.Text('ID: ${qrCode.substring(qrCode.length - 8)}',
                  style: const pw.TextStyle(fontSize: 7)),
              pw.SizedBox(height: 2 * mm),
              pw.Text('IDENTITY ONLY',
                  style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
              pw.Text('NOT SAFETY CERTIFIED',
                  style: const pw.TextStyle(fontSize: 6)),
            ],
          )),
        ],
      ),
    ),
  ));
  return pdf.save();
}

String _wrapSerial(String serial) {
  final pieces = <String>[];
  for (var i = 0; i < serial.length; i += 20) {
    final last = i + 20 > serial.length ? serial.length : i + 20;
    pieces.add(serial.substring(i, last));
  }
  return pieces.join('\n');
}
