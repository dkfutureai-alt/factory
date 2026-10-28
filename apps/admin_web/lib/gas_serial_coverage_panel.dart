import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Shows attestation completeness only. Neither location nor cylinder safety
/// is proven by the existence of an Inventory transaction's serial links.
class GasSerialCoveragePanel extends StatefulWidget {
  const GasSerialCoveragePanel({required this.factoryId, super.key});

  final String factoryId;

  @override
  State<GasSerialCoveragePanel> createState() => _GasSerialCoveragePanelState();
}

class _GasSerialCoveragePanelState extends State<GasSerialCoveragePanel> {
  bool onlyMissing = true;
  late Future<List<Map<String, dynamic>>> future = load();

  Future<List<Map<String, dynamic>>> load() async {
    final rows = await Supabase.instance.client.rpc(
      'gas_serial_transaction_coverage',
      params: {
        'p_factory_id': widget.factoryId,
        'p_limit': 100,
        'p_missing_only': onlyMissing,
      },
    ) as List<dynamic>;
    return rows
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  void refresh() => setState(() => future = load());

  @override
  void didUpdateWidget(covariant GasSerialCoveragePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.factoryId != widget.factoryId) {
      refresh();
    }
  }

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(FactorySpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cylinder serial evidence gaps',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: FactorySpacing.xs),
              const Text(
                'Read-only comparison of posted cylinder/returnable '
                'Inventory quantities with linked serial records. '
                'Even full coverage does not prove physical custody, '
                'inspection certification, or location accuracy.',
              ),
              const SizedBox(height: FactorySpacing.sm),
              Wrap(
                spacing: FactorySpacing.md,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilterChip(
                    selected: onlyMissing,
                    label: const Text('Show incomplete only'),
                    onSelected: (selected) {
                      setState(() {
                        onlyMissing = selected;
                        future = load();
                      });
                    },
                  ),
                  IconButton(
                    tooltip: 'Reload serial evidence',
                    onPressed: refresh,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const LinearProgressIndicator();
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(FactorySpacing.sm),
                      child: Text('Evidence report unavailable: ${snapshot.error}'),
                    );
                  }
                  final rows = snapshot.requireData;
                  if (rows.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(FactorySpacing.sm),
                      child: Text(
                        'No matching movements in this view. '
                        'This does not mean all factory cylinders are accounted for.',
                      ),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Showing ${rows.length} recent transactions, '
                        'maximum 100. This is not a full historical total.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: FactorySpacing.sm),
                      for (final row in rows)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            row['coverage_status'] == 'complete'
                                ? Icons.check_circle_outline
                                : Icons.warning_amber_outlined,
                            color: row['coverage_status'] == 'complete'
                                ? null
                                : Theme.of(context).colorScheme.error,
                          ),
                          title: Text(
                            '${row['transaction_no']} · ${row['item_sku']}',
                          ),
                          subtitle: Text(
                            '${row['transaction_type']} · '
                            'Linked ${row['linked_serial_count']} of '
                            '${row['posted_quantity']} units · '
                            'Unlinked ${row['unlinked_quantity']}',
                          ),
                          trailing: Text(
                            '${row['coverage_status']}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      );
}
