import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/scanner_port.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key, required this.scanner});

  final ScannerPort scanner;

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final _manualCode = TextEditingController();
  ScanLookupResult? _result;
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _manualCode.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final code = _manualCode.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter an SKU, barcode or QR identifier.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await widget.scanner.resolveCode(code);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _result = result;
      _error = result == null ? 'No inventory item found for this code.' : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      appBar: AppBar(
        foregroundColor: Colors.white,
        backgroundColor: const Color(0xFF0B1220),
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Scan item', style: TextStyle(fontWeight: FontWeight.w800)),
          Text('Central Warehouse • Material Issue', style: TextStyle(fontSize: 12, color: Color(0xFF98A2B3))),
        ]),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          children: [
            Container(
              height: 390,
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Stack(alignment: Alignment.center, children: [
                Container(
                  width: 286,
                  height: 286,
                  decoration: BoxDecoration(color: const Color(0xFF172033), borderRadius: BorderRadius.circular(18)),
                ),
                const SizedBox(width: 250, child: Divider(color: Color(0xFF5B8DEF), thickness: 3)),
                const Positioned(bottom: 24, child: Text('Align QR code or barcode inside the frame', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12))),
                if (!widget.scanner.supportsCamera)
                  Container(
                    margin: const EdgeInsets.all(42),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xDD0B1220), borderRadius: BorderRadius.circular(12)),
                    child: const Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.qr_code_scanner, size: 44, color: Colors.white),
                      SizedBox(height: 10),
                      Text('Camera scanner integration pending', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      SizedBox(height: 6),
                      Text('Use manual code entry below in this preview build.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
                    ]),
                  ),
              ]),
            ),
            const SizedBox(height: 18),
            if (_result != null) _ScanResultCard(result: _result!),
            if (_result != null) const SizedBox(height: 18),
            const Text("Can't scan?", style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: _manualCode,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _lookup(),
              decoration: const InputDecoration(
                hintText: 'Enter SKU / barcode / QR manually',
                prefixIcon: Icon(Icons.keyboard),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Color(0xFFFFB4AB), fontSize: 12)),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loading ? null : _lookup,
              icon: _loading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.search),
              label: const Text('Use manual entry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanResultCard extends StatelessWidget {
  const _ScanResultCard({required this.result});
  final ScanLookupResult result;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('LAST SCANNED', style: TextStyle(color: AppTheme.muted, fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text(result.sku, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.text)),
            const SizedBox(height: 3),
            Text(result.name, style: const TextStyle(color: AppTheme.muted)),
            const SizedBox(height: 14),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFECFDF3), borderRadius: BorderRadius.circular(999)),
                child: Text('${result.availableQuantity.toStringAsFixed(0)} ${result.unit} available', style: const TextStyle(color: AppTheme.success, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              TextButton(onPressed: () {}, child: const Text('View item')),
            ]),
          ]),
        ),
      );
}
