import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/inventory_repository.dart';
import '../domain/inventory_models.dart';

class InventoryDashboardPage extends StatelessWidget {
  const InventoryDashboardPage({super.key, required this.repository});

  final InventoryRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Inventory', style: TextStyle(fontWeight: FontWeight.w800)),
          Text('Central Warehouse', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
        ]),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).pushNamed('/scanner'),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan item'),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.add), label: const Text('Stock entry')),
          ),
        ],
      ),
      body: FutureBuilder<InventoryOverview>(
        future: repository.loadOverview(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text('Unable to load inventory.'));
          }
          return _InventoryBody(data: snapshot.requireData);
        },
      ),
    );
  }
}

class _InventoryBody extends StatelessWidget {
  const _InventoryBody({required this.data});
  final InventoryOverview data;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Live stock position • 14 Oct 2026', style: TextStyle(color: AppTheme.muted)),
        const SizedBox(height: 18),
        LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1080 ? 4 : constraints.maxWidth >= 650 ? 2 : 1;
          return GridView.count(
            crossAxisCount: columns,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: columns == 1 ? 3.4 : 2.0,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _InventoryKpi(label: 'Stock value', value: '₹${(data.stockValue / 100000).toStringAsFixed(1)}L', subtitle: '${data.activeSkuCount} active SKUs'),
              _InventoryKpi(label: 'Low stock', value: '${data.lowStockCount}', subtitle: 'at / below reorder', accent: AppTheme.warning),
              _InventoryKpi(label: "Today's movements", value: '${data.todayMovements}', subtitle: 'receipts, issues & transfers'),
              _InventoryKpi(label: 'Blocked / damaged', value: '${data.blockedOrDamagedCount}', subtitle: 'requires review', accent: AppTheme.danger),
            ],
          );
        }),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(spacing: 12, runSpacing: 12, children: [
              const SizedBox(width: 420, child: TextField(decoration: InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'SKU, item name, barcode or batch'))),
              SizedBox(width: 180, child: DropdownButtonFormField<String>(isExpanded: true, initialValue: 'All categories', items: const [DropdownMenuItem(value: 'All categories', child: Text('All categories', overflow: TextOverflow.ellipsis))], onChanged: (_) {})),
              SizedBox(width: 180, child: DropdownButtonFormField<String>(isExpanded: true, initialValue: 'All warehouses', items: const [DropdownMenuItem(value: 'All warehouses', child: Text('All warehouses', overflow: TextOverflow.ellipsis))], onChanged: (_) {})),
              SizedBox(width: 180, child: DropdownButtonFormField<String>(isExpanded: true, initialValue: 'All status', items: const [DropdownMenuItem(value: 'All status', child: Text('All status', overflow: TextOverflow.ellipsis))], onChanged: (_) {})),
            ]),
          ),
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Items', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              LayoutBuilder(builder: (context, constraints) {
                if (constraints.maxWidth < 760) {
                  return Column(children: data.items.map((item) => _InventoryItemCard(item: item)).toList());
                }
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('SKU / Item')),
                      DataColumn(label: Text('Category')),
                      DataColumn(label: Text('Location')),
                      DataColumn(label: Text('On hand'), numeric: true),
                      DataColumn(label: Text('Reorder'), numeric: true),
                      DataColumn(label: Text('Status')),
                    ],
                    rows: data.items.map((item) => DataRow(cells: [
                      DataCell(SizedBox(width: 250, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(item.sku, style: const TextStyle(fontWeight: FontWeight.w700)), Text(item.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppTheme.muted))]))),
                      DataCell(Text(item.category)),
                      DataCell(Text(item.location)),
                      DataCell(Text('${item.onHand.toStringAsFixed(item.onHand.truncateToDouble() == item.onHand ? 0 : 2)} ${item.unit}')),
                      DataCell(Text('${item.reorderLevel.toStringAsFixed(0)} ${item.unit}')),
                      DataCell(_StockStatus(low: item.isLowStock)),
                    ])).toList(),
                  ),
                );
              }),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _InventoryKpi extends StatelessWidget {
  const _InventoryKpi({required this.label, required this.value, required this.subtitle, this.accent = AppTheme.text});
  final String label;
  final String value;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 13)),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: accent)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
          ]),
        ),
      );
}

class _InventoryItemCard extends StatelessWidget {
  const _InventoryItemCard({required this.item});
  final InventoryItemSummary item;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(border: Border.all(color: AppTheme.border), borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.sku, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(item.name, style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
              const SizedBox(height: 4),
              Text(item.location, style: const TextStyle(fontSize: 12)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${item.onHand.toStringAsFixed(0)} ${item.unit}', style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              _StockStatus(low: item.isLowStock),
            ]),
          ]),
        ),
      );
}

class _StockStatus extends StatelessWidget {
  const _StockStatus({required this.low});
  final bool low;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(color: low ? const Color(0xFFFFF7ED) : const Color(0xFFECFDF3), borderRadius: BorderRadius.circular(999)),
        child: Text(low ? 'Low stock' : 'Healthy', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: low ? AppTheme.warning : AppTheme.success)),
      );
}
