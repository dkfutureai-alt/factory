import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InventoryScannerPage extends StatefulWidget {
  const InventoryScannerPage({required this.organizationId, super.key});

  /// The currently opened FactoryOS workspace, not the first membership.
  final String organizationId;

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
  Map<String, dynamic>? containerAsset;

  @override
  void dispose() {
    manual.dispose();
    scanner.dispose();
    super.dispose();
  }

  Future<void> lookup(String rawCode) async {
    final code = rawCode.trim();
    if (code.length < 2 || busy) return;
    setState(() {
      busy = true;
      error = null;
      lastCode = code;
      // Clear prior results immediately: never display the previous
      // cylinder or stock as though it belongs to the new scan.
      containerAsset = null;
      rows = const [];
    });
    try {
      if (Supabase.instance.client.auth.currentUser == null) {
        throw StateError('Authentication required.');
      }
      final organizationId = widget.organizationId;
      final normalizedSerial = code.toUpperCase();
      final byQr = await Supabase.instance.client
          .from('gas_container_assets')
          .select('id,serial_number,qr_code,container_type,ownership,state,condition,test_due_on,factory_id')
          .eq('organization_id', organizationId)
          .eq('qr_code', code)
          .limit(1);
      final bySerial = byQr.isNotEmpty
          ? byQr
          : await Supabase.instance.client
              .from('gas_container_assets')
              .select('id,serial_number,qr_code,container_type,ownership,state,condition,test_due_on,factory_id')
              .eq('organization_id', organizationId)
              .eq('serial_number', normalizedSerial)
              .limit(1);
      final matchedAsset = bySerial.isEmpty
          ? null
          : Map<String, dynamic>.from(bySerial.first);
      List<Map<String, dynamic>> found = const [];
      if (matchedAsset == null) {
        final result = await Supabase.instance.client.rpc(
          'inventory_lookup_scan',
          params: {'p_organization_id': organizationId, 'p_code': code},
        );
        found = (result as List<dynamic>)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
      }
      if (!mounted) return;
      setState(() {
        containerAsset = matchedAsset;
        rows = found;
        error = matchedAsset == null && found.isEmpty
            ? 'No accessible container or Inventory item matched this code.'
            : null;
      });
    } catch (exception) {
      if (mounted) {
        setState(() {
          rows = const [];
          containerAsset = null;
          error = _errorText(exception);
        });
      }
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
            if (containerAsset != null) ...[
              const SizedBox(height: FactorySpacing.md),
              Text(
                'Serialized cylinder / Dura',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(FactorySpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        containerAsset!['serial_number'] as String,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text('QR: ${containerAsset!['qr_code']}'),
                      Text('Type: ${_title(containerAsset!['container_type'] as String)}'),
                      Text('State: ${_title(containerAsset!['state'] as String)}'),
                      Text('Condition: ${_title(containerAsset!['condition'] as String)}'),
                      Text('Test due: ${containerAsset!['test_due_on'] ?? 'Not recorded'}'),
                      const SizedBox(height: FactorySpacing.sm),
                      const Text(
                        'Identity only. The scan does not certify safety, confirm customer custody, or change stock.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
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
