import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/inventory_item_detail_repository.dart';
import '../data/inventory_repository.dart';
import '../domain/inventory_models.dart';
import 'inventory_item_detail_page.dart';

class InventoryDashboardPage extends StatelessWidget {
  const InventoryDashboardPage({
    super.key,
    required this.repository,
    this.detailRepository,
  });

  final InventoryRepository repository;
  final InventoryItemDetailRepository? detailRepository;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Inventory', style: TextStyle(fontWeight: FontWeight.w800)),
              Text('Central Warehouse', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.of(context).pushNamed('/scanner'),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan item'),
            ),
            const SizedBox(width: 16),
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
            final data = snapshot.requireData;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text('Current stock position', style: TextStyle(color: AppTheme.muted)),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    _Metric(label: 'Stock value', value: '₹${(data.stockValue / 100000).toStringAsFixed(1)}L'),
                    _Metric(label: 'Low stock', value: '${data.lowStockCount}', accent: AppTheme.warning),
                    _Metric(label: "Today's movements", value: '${data.todayMovements}'),
                    _Metric(label: 'Blocked / damaged', value: '${data.blockedOrDamagedCount}', accent: AppTheme.danger),
                  ],
                ),
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        const SizedBox(
                          width: 420,
                          child: TextField(
                            decoration: InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText: 'SKU, item name, barcode or batch',
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 180,
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: 'All categories',
                            items: const [
                              DropdownMenuItem(
                                value: 'All categories',
                                child: Text('All categories', overflow: TextOverflow.ellipsis),
                              ),
                            ],
                            onChanged: (_) {},
                          ),
                        ),
                        SizedBox(
                          width: 180,
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: 'All warehouses',
                            items: const [
                              DropdownMenuItem(
                                value: 'All warehouses',
                                child: Text('All warehouses', overflow: TextOverflow.ellipsis),
                              ),
                            ],
                            onChanged: (_) {},
                          ),
                        ),
                        SizedBox(
                          width: 180,
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: 'All status',
                            items: const [
                              DropdownMenuItem(
                                value: 'All status',
                                child: Text('All status', overflow: TextOverflow.ellipsis),
                              ),
                            ],
                            onChanged: (_) {},
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Items', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        ...data.items.map(
                          (item) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            onTap: () {
                              final detail = detailRepository;
                              if (detail == null) {
                                Navigator.of(context).pushNamed('/inventory/item');
                                return;
                              }
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => InventoryItemDetailPage(
                                    repository: detail,
                                    sku: item.sku,
                                  ),
                                ),
                              );
                            },
                            title: Text(
                              '${item.sku} • ${item.name}',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: Text('${item.category} • ${item.location}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${item.onHand.toStringAsFixed(0)} ${item.unit}',
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(width: 10),
                                _StockStatus(low: item.isLowStock),
                                const SizedBox(width: 6),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.accent = AppTheme.text});
  final String label, value;
  final Color accent;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 245,
        height: 124,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
                const SizedBox(height: 8),
                Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: accent)),
              ],
            ),
          ),
        ),
      );
}

class _StockStatus extends StatelessWidget {
  const _StockStatus({required this.low});
  final bool low;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: low ? const Color(0xFFFFF7ED) : const Color(0xFFECFDF3),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          low ? 'Low stock' : 'Healthy',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: low ? AppTheme.warning : AppTheme.success,
          ),
        ),
      );
}
