class ScanLookupResult {
  const ScanLookupResult({
    required this.code,
    required this.sku,
    required this.name,
    required this.availableQuantity,
    required this.unit,
  });

  final String code;
  final String sku;
  final String name;
  final double availableQuantity;
  final String unit;
}

abstract interface class ScannerPort {
  bool get supportsCamera;
  Future<ScanLookupResult?> resolveCode(String code);
}

/// Preview/manual scanner adapter. Camera support remains disabled until the
/// Android/iOS platform scaffold and barcode plugin permissions are added.
final class PreviewScannerPort implements ScannerPort {
  const PreviewScannerPort();

  @override
  bool get supportsCamera => false;

  @override
  Future<ScanLookupResult?> resolveCode(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized == 'RM-STEEL-001' || normalized == '890100000001' || normalized == 'QR-RM-STEEL-001') {
      return const ScanLookupResult(
        code: 'QR-RM-STEEL-001',
        sku: 'RM-STEEL-001',
        name: 'MS Steel Sheet 2mm',
        availableQuantity: 1240,
        unit: 'kg',
      );
    }
    if (normalized == 'RM-PIPE-001' || normalized == '890100000002' || normalized == 'QR-RM-PIPE-001') {
      return const ScanLookupResult(
        code: 'QR-RM-PIPE-001',
        sku: 'RM-PIPE-001',
        name: 'Industrial Pipe 25mm',
        availableQuantity: 182,
        unit: 'pcs',
      );
    }
    return null;
  }
}
