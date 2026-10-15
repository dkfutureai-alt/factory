import 'package:factoryos/features/scanner/domain/scanner_port.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const scanner = PreviewScannerPort();

  test('preview scanner resolves SKU barcode and QR to the same item', () async {
    final sku = await scanner.resolveCode('RM-STEEL-001');
    final barcode = await scanner.resolveCode('890100000001');
    final qr = await scanner.resolveCode('qr-rm-steel-001');

    expect(scanner.supportsCamera, isFalse);
    expect(sku?.sku, 'RM-STEEL-001');
    expect(barcode?.sku, sku?.sku);
    expect(qr?.sku, sku?.sku);
    expect(qr?.availableQuantity, 1240);
  });

  test('preview scanner returns null for unknown code', () async {
    expect(await scanner.resolveCode('UNKNOWN-001'), isNull);
  });
}
