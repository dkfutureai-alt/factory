import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/warehouse_repository.dart';
import '../domain/warehouse_models.dart';

class WarehouseTransferDetailPage extends StatefulWidget {
  const WarehouseTransferDetailPage({
    super.key,
    required this.repository,
    required this.transferNumber,
  });

  final WarehouseRepository repository;
  final String transferNumber;

  @override
  State<WarehouseTransferDetailPage> createState() => _WarehouseTransferDetailPageState();
}

class _WarehouseTransferDetailPageState extends State<WarehouseTransferDetailPage> {
  late Future<WarehouseTransferDetail> _transferFuture;
  bool _submitting = false;
  String? _commandError;

  @override
  void initState() {
    super.initState();
    _transferFuture = widget.repository.loadTransfer(widget.transferNumber);
  }

  Future<void> _completeTransfer() async {
    if (_submitting || !widget.repository.supportsMutations) return;
    setState(() {
      _submitting = true;
      _commandError = null;
    });
    try {
      final updated = await widget.repository.completeTransfer(widget.transferNumber);
      if (!mounted) return;
      setState(() => _transferFuture = Future.value(updated));
    } catch (error) {
      if (!mounted) return;
      setState(() => _commandError = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.transferNumber, style: const TextStyle(fontWeight: FontWeight.w800)),
            const Text(
              'Warehouse transfer • Inventory ledger controlled',
              style: TextStyle(fontSize: 12, color: AppTheme.muted),
            ),
          ],
        ),
      ),
      body: FutureBuilder<WarehouseTransferDetail>(
        future: _transferFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('Unable to load warehouse transfer.'));
          }
          final transfer = snapshot.requireData;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  _Metric(label: 'Status', value: transfer.status, accent: AppTheme.brand),
                  _Metric(label: 'Lines', value: '${transfer.lines.length}'),
                  _Metric(label: 'Total quantity', value: transfer.totalQuantity.toStringAsFixed(0)),
                  _Metric(
                    label: 'Ledger pair',
                    value: transfer.ledgerReconciled ? 'Posted' : 'Pending',
                    accent: transfer.ledgerReconciled ? AppTheme.success : AppTheme.warning,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final lines = _TransferLines(transfer: transfer);
                  final gate = _CompletionGate(
                    transfer: transfer,
                    liveMutations: widget.repository.supportsMutations,
                    submitting: _submitting,
                    commandError: _commandError,
                    onComplete: transfer.canComplete ? _completeTransfer : null,
                  );
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

class _TransferLines extends StatelessWidget {
  const _TransferLines({required this.transfer});
  final WarehouseTransferDetail transfer;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Transfer lines', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                '${transfer.sourceWarehouse} → ${transfer.destinationWarehouse}',
                style: const TextStyle(color: AppTheme.muted),
              ),
              const SizedBox(height: 12),
              ...transfer.lines.map(
                (line) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${line.sku} • ${line.name}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(
                    '${line.batchNumber ?? 'No batch'}\n${line.fromLocation} → ${line.toLocation}',
                  ),
                  isThreeLine: true,
                  trailing: Text(
                    '${line.safeQuantity.toStringAsFixed(0)} ${line.unit}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _CompletionGate extends StatelessWidget {
  const _CompletionGate({
    required this.transfer,
    required this.liveMutations,
    required this.submitting,
    required this.commandError,
    required this.onComplete,
  });

  final WarehouseTransferDetail transfer;
  final bool liveMutations;
  final bool submitting;
  final String? commandError;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Completion gate', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              _GateRow(ok: transfer.lines.isNotEmpty, label: 'Transfer lines validated'),
              _GateRow(ok: transfer.outLedgerPosted, label: 'transfer_out ledger posted'),
              _GateRow(ok: transfer.inLedgerPosted, label: 'transfer_in ledger posted'),
              const SizedBox(height: 14),
              Text('Reason: ${transfer.reason}', style: const TextStyle(color: AppTheme.muted)),
              const SizedBox(height: 6),
              Text('Assigned: ${transfer.assignee}', style: const TextStyle(color: AppTheme.muted)),
              if (commandError != null) ...[
                const SizedBox(height: 12),
                Text(commandError!, style: const TextStyle(color: AppTheme.danger, fontSize: 12, fontWeight: FontWeight.w700)),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: !liveMutations || submitting ? null : onComplete,
                  icon: submitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.swap_horiz),
                  label: Text(transfer.ledgerReconciled ? 'Transfer completed' : 'Complete transfer'),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                liveMutations
                    ? 'Live command mode. Completion runs the verified atomic transfer RPC; stock remains ledger-controlled.'
                    : 'Preview repository only. Live stock-changing commands are intentionally disabled.',
                style: const TextStyle(fontSize: 12, color: AppTheme.muted),
              ),
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
