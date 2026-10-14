import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/dispatch_repository.dart';
import '../domain/dispatch_models.dart';

class DispatchLoadDetailPage extends StatelessWidget {
  const DispatchLoadDetailPage({
    super.key,
    required this.repository,
    required this.dispatchNumber,
  });

  final DispatchRepository repository;
  final String dispatchNumber;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dispatchNumber, style: const TextStyle(fontWeight: FontWeight.w800)),
            const Text('Dispatch load • ledger + checks + trip gate', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pushNamed('/delivery'),
              icon: const Icon(Icons.local_shipping_outlined),
              label: const Text('Delivery queue'),
            ),
          ),
        ],
      ),
      body: FutureBuilder<DispatchLoadDetail>(
        future: repository.loadDispatch(dispatchNumber),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) return const Center(child: Text('Unable to load dispatch.'));
          final dispatch = snapshot.requireData;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  _Metric(label: 'Status', value: dispatch.status, accent: _statusColor(dispatch.status)),
                  _Metric(label: 'Load', value: '${(dispatch.loadedRate * 100).toStringAsFixed(0)}%', accent: AppTheme.brand),
                  _Metric(label: 'Packages', value: '${dispatch.packageCount}'),
                  _Metric(label: 'Weight', value: '${dispatch.weightKg.toStringAsFixed(0)} kg'),
                ],
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final lines = _LoadLines(dispatch: dispatch);
                  final gate = _FinalizeGate(dispatch: dispatch);
                  if (constraints.maxWidth > 920) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: lines),
                        const SizedBox(width: 16),
                        Expanded(child: gate),
                      ],
                    );
                  }
                  return Column(children: [lines, const SizedBox(height: 16), gate]);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Color _statusColor(String status) {
    if (status == 'Dispatched') return AppTheme.success;
    if (status == 'Blocked') return AppTheme.danger;
    return AppTheme.brand;
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.accent = AppTheme.text});
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 245,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
                const SizedBox(height: 8),
                Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: accent)),
              ],
            ),
          ),
        ),
      );
}

class _LoadLines extends StatelessWidget {
  const _LoadLines({required this.dispatch});
  final DispatchLoadDetail dispatch;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${dispatch.salesOrderNumber} • ${dispatch.customer}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                '${dispatch.loadingBay} • ${dispatch.vehicleRegistration} • ${dispatch.driverName}',
                style: const TextStyle(color: AppTheme.muted),
              ),
              const SizedBox(height: 14),
              ...dispatch.lines.map(
                (line) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(line.ledgerPosted ? Icons.verified : Icons.pending_actions, color: line.ledgerPosted ? AppTheme.success : AppTheme.warning),
                  title: Text('${line.sku} • ${line.name}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${line.batchNumber ?? 'No batch'} • Ledger ${line.ledgerPosted ? 'posted' : 'pending'}'),
                  trailing: Text(
                    '${line.safeLoadedQuantity.toStringAsFixed(0)} / ${line.safePlannedQuantity.toStringAsFixed(0)} ${line.unit}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _FinalizeGate extends StatelessWidget {
  const _FinalizeGate({required this.dispatch});
  final DispatchLoadDetail dispatch;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Finalization gate', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              _GateRow(ok: dispatch.linesFullyLoaded, label: 'All load quantities reconciled'),
              _GateRow(ok: dispatch.ledgerReconciled, label: 'Posted sales_dispatch ledger'),
              _GateRow(ok: dispatch.requiredChecksComplete, label: 'Required documents & checks complete'),
              _GateRow(ok: dispatch.tripAssigned, label: 'Trip ${dispatch.tripNumber.isEmpty ? 'pending' : dispatch.tripNumber}'),
              const Divider(height: 28),
              ...dispatch.checks.map((check) => _GateRow(ok: check.complete, label: check.label)),
              const SizedBox(height: 8),
              if (dispatch.status == 'Dispatched') ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pushNamed('/delivery/detail'),
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: const Text('Open Delivery handoff'),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This preview represents a finalized dispatch backed by the seeded posted stock ledger.',
                  style: TextStyle(fontSize: 12, color: AppTheme.muted),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('Finalize dispatch'),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Preview repository only. The verified finalize RPC will be connected after FactoryOS Supabase is available.',
                  style: TextStyle(fontSize: 12, color: AppTheme.muted),
                ),
              ],
            ],
          ),
        ),
      );
}

class _GateRow extends StatelessWidget {
  const _GateRow({required this.ok, required this.label});
  final bool ok;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(ok ? Icons.check_circle : Icons.schedule, color: ok ? AppTheme.success : AppTheme.warning),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
          ],
        ),
      );
}
