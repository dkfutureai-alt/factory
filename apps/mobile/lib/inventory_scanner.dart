import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InventoryScannerPage extends StatefulWidget {
  const InventoryScannerPage({super.key});

  @override
  State<InventoryScannerPage> createState() => _InventoryScannerPageState();
}

class _InventoryScannerPageState extends State<InventoryScannerPage> {
  final manual = TextEditingController();
  final scanner = MobileScannerController();
  bool busy = false;
  bool cameraEnabled = true;
  String? error;
  String? lastCode;
  List<Map<String, dynamic>> rows = const [];

  @override
  void dispose() {
    manual.dispose();
    scanner.dispose();
    super.dispose();
  }

  Future<String> _organizationId() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw StateError('Authentication required.');
    final membership = await Supabase.instance.client
        .from('organization_members')
        .select('organization_id')
        .eq('user_id', user.id)
        .eq('is_active', true)
        .limit(1)
        .maybeSingle();
    if (membership == null) {
      throw StateError('No active organization membership.');
    }
    return membership['organization_id'] as String;
  }

  Future<void> lookup(String rawCode) async {
    final code = rawCode.trim();
    if (code.length < 2 || busy) return;
    setState(() {
      busy = true;
      error = null;
      lastCode = code;
    });
    try {
      final organizationId = await _organizationId();
      final result = await Supabase.instance.client.rpc(
        'inventory_lookup_scan',
        params: {'p_organization_id': organizationId, 'p_code': code},
      );
      final found = (result as List<dynamic>)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        rows = found;
        error = found.isEmpty ? 'No inventory item matched this code.' : null;
      });
    } catch (exception) {
      if (mounted) setState(() => error = _errorText(exception));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void onDetect(BarcodeCapture capture) {
    if (capture.barcodes.isEmpty) return;
    final value = capture.barcodes.first.rawValue;
    if (value == null || value.trim().isEmpty || value == lastCode) return;
    manual.text = value;
    lookup(value);
  }

  Future<void> toggleCamera() async {
    if (cameraEnabled) {
      await scanner.stop();
    } else {
      await scanner.start();
    }
    if (mounted) setState(() => cameraEnabled = !cameraEnabled);
  }

  @override
  Widget build(BuildContext context) {
    final item = rows.isEmpty ? null : rows.first;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory scan'),
        actions: [
          IconButton(
            tooltip: cameraEnabled ? 'Pause camera' : 'Start camera',
            onPressed: toggleCamera,
            icon: Icon(
              cameraEnabled
                  ? Icons.pause_circle_outline
                  : Icons.play_circle_outline,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(FactorySpacing.md),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(FactoryRadius.lg),
              child: SizedBox(
                height: 260,
                child: cameraEnabled
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          MobileScanner(
                            controller: scanner,
                            onDetect: onDetect,
                          ),
                          Center(
                            child: Container(
                              width: 250,
                              height: 130,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          ),
                        ],
                      )
                    : const ColoredBox(
                        color: Colors.black12,
                        child: Center(child: Text('Camera paused')),
                      ),
              ),
            ),
            const SizedBox(height: FactorySpacing.md),
            TextField(
              controller: manual,
              textInputAction: TextInputAction.search,
              onSubmitted: lookup,
              decoration: InputDecoration(
                labelText: 'Barcode, QR code or SKU',
                prefixIcon: const Icon(Icons.qr_code_scanner),
                suffixIcon: IconButton(
                  onPressed: busy ? null : () => lookup(manual.text),
                  icon: const Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(height: FactorySpacing.xs),
            const Text(
              'You can also use a connected handheld scanner; scanned keyboard input works in the field above.',
            ),
            if (busy) ...[
              const SizedBox(height: FactorySpacing.md),
              const LinearProgressIndicator(),
            ],
            if (error != null) ...[
              const SizedBox(height: FactorySpacing.md),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(error!),
                ),
              ),
            ],
            if (item != null) ...[
              const SizedBox(height: FactorySpacing.lg),
              Text(
                'Item found',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: FactorySpacing.sm),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(FactorySpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['item_name'] as String,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${item['sku']} · ${_title(item['item_type'] as String)} · ${item['unit_code']}',
                      ),
                      if (item['barcode'] != null)
                        Text('Barcode: ${item['barcode']}'),
                      if (item['qr_code'] != null)
                        Text('QR: ${item['qr_code']}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: FactorySpacing.md),
              Text(
                'Accessible stock',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: FactorySpacing.sm),
              for (final row in rows)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.warehouse_outlined),
                    title: Text(row['location_name'] as String),
                    subtitle: Text(row['factory_name'] as String),
                    trailing: Text(
                      '${_number(row['quantity'])} ${row['unit_code']}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

String _number(dynamic value) {
  final parsed = value is num
      ? value.toDouble()
      : double.tryParse('$value') ?? 0;
  return parsed == parsed.roundToDouble()
      ? parsed.toStringAsFixed(0)
      : parsed.toStringAsFixed(2);
}

String _title(String value) => value
    .split('_')
    .map(
      (part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}',
    )
    .join(' ');
String _errorText(Object error) =>
    error is PostgrestException ? error.message : '$error';
