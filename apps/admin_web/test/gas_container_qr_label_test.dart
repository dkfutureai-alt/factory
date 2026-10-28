import 'dart:convert';

import 'package:factoryos_admin_web/gas_container_qr_label.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const qr = 'FA-0123456789ABCDEF0123456789ABCDEF';

  test('creates a PDF label for a physical cylinder', () async {
    final bytes = await buildGasContainerQrLabel(
      qrCode: qr,
      serialNumber: 'CYL-2026-A001',
      containerType: 'cylinder',
    );
    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
    expect(bytes.length, greaterThan(750));
  });

  test('Dura serials at the supported length generate a PDF', () async {
    final bytes = await buildGasContainerQrLabel(
      qrCode: qr,
      serialNumber: 'D' * 80,
      containerType: 'dura',
    );
    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
    expect(bytes.length, greaterThan(750));
  });

  test('rejects foreign or malformed QR identifiers', () async {
    await expectLater(
      buildGasContainerQrLabel(
        qrCode: 'https://untrusted.example/qr',
        serialNumber: 'CYL-0001',
        containerType: 'cylinder',
      ),
      throwsArgumentError,
    );
  });

  test('rejects non-normalized or unsafe serial strings', () async {
    await expectLater(
      buildGasContainerQrLabel(
        qrCode: qr,
        serialNumber: 'lower-case',
        containerType: 'cylinder',
      ),
      throwsArgumentError,
    );
  });

  test('rejects unsupported container types', () async {
    await expectLater(
      buildGasContainerQrLabel(
        qrCode: qr,
        serialNumber: 'CYL-0001',
        containerType: 'unknown',
      ),
      throwsArgumentError,
    );
  });
}
