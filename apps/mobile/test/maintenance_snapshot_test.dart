import 'package:factoryos_mobile/maintenance_technician.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const assetId = 'asset-1';
  const workOrderId = 'wo-1';

  TechnicianMaintenanceSnapshot snapshot() => TechnicianMaintenanceSnapshot(
        assets: const [
          {
            'id': assetId,
            'asset_code': 'AC-001',
            'qr_code': 'AAROHAN:ASSET:AC-001',
            'name': 'Air Compressor-1',
          },
        ],
        workOrders: const [],
        tasks: const [],
        updates: const [],
        downtime: const [
          {
            'id': 'down-open',
            'work_order_id': workOrderId,
            'ended_at': null,
          },
          {
            'id': 'down-closed',
            'work_order_id': 'wo-2',
            'ended_at': '2026-10-17T10:00:00Z',
          },
        ],
        plans: const [],
        items: const [
          {
            'id': 'spare-1',
            'item_type': 'spare',
            'name': 'Oil Filter',
          },
          {
            'id': 'consumable-1',
            'item_type': 'consumable',
            'name': 'Hydraulic Oil',
          },
          {
            'id': 'raw-1',
            'item_type': 'raw_material',
            'name': 'Raw Material',
          },
        ],
        locations: const [],
        usage: const [],
      );

  test('asset scan matches configured QR value', () {
    final data = snapshot();
    expect(data.findAssetByCode('AAROHAN:ASSET:AC-001')?['id'], assetId);
  });

  test('asset scan also matches asset code case-insensitively', () {
    final data = snapshot();
    expect(data.findAssetByCode('ac-001')?['id'], assetId);
  });

  test('spareItems contains only spare and consumable inventory items', () {
    final data = snapshot();
    expect(
      data.spareItems.map((row) => row['id']).toSet(),
      {'spare-1', 'consumable-1'},
    );
  });

  test('openDowntime returns only the active downtime event', () {
    final data = snapshot();
    expect(data.openDowntime(workOrderId)?['id'], 'down-open');
    expect(data.openDowntime('wo-2'), isNull);
  });
}
