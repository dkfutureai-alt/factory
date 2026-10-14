import 'package:factoryos/features/dispatch/domain/dispatch_models.dart';
import 'package:factoryos/features/warehouse/domain/warehouse_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('warehouse transfer quantities never aggregate negative values', () {
    const transfer = WarehouseTransferDetail(
      transferNumber: 'TRF-1',
      status: 'Ready',
      sourceWarehouse: 'RM-WH',
      destinationWarehouse: 'STAGE',
      reason: 'Production staging',
      assignee: 'Team A',
      outLedgerPosted: false,
      inLedgerPosted: false,
      lines: [
        WarehouseTransferLine(
          sku: 'A',
          name: 'A',
          fromLocation: 'A1',
          toLocation: 'S1',
          quantity: 10,
          unit: 'pcs',
        ),
        WarehouseTransferLine(
          sku: 'B',
          name: 'B',
          fromLocation: 'B1',
          toLocation: 'S1',
          quantity: -4,
          unit: 'pcs',
        ),
      ],
    );
    expect(transfer.totalQuantity, 10);
    expect(transfer.canComplete, isTrue);
  });

  test('warehouse completion state requires both ledger sides', () {
    const incomplete = WarehouseTransferDetail(
      transferNumber: 'TRF-1',
      status: 'Ready',
      sourceWarehouse: 'RM-WH',
      destinationWarehouse: 'STAGE',
      reason: 'Staging',
      assignee: 'Team',
      outLedgerPosted: true,
      inLedgerPosted: false,
      lines: [
        WarehouseTransferLine(sku: 'A', name: 'A', fromLocation: 'A1', toLocation: 'S1', quantity: 1, unit: 'pc'),
      ],
    );
    expect(incomplete.ledgerReconciled, isFalse);
    expect(incomplete.canComplete, isTrue);

    const reconciled = WarehouseTransferDetail(
      transferNumber: 'TRF-1',
      status: 'Completed',
      sourceWarehouse: 'RM-WH',
      destinationWarehouse: 'STAGE',
      reason: 'Staging',
      assignee: 'Team',
      outLedgerPosted: true,
      inLedgerPosted: true,
      lines: [
        WarehouseTransferLine(sku: 'A', name: 'A', fromLocation: 'A1', toLocation: 'S1', quantity: 1, unit: 'pc'),
      ],
    );
    expect(reconciled.ledgerReconciled, isTrue);
    expect(reconciled.canComplete, isFalse);
  });

  test('dispatch loaded rate is bounded and zero-safe', () {
    const empty = DispatchLoadDetail(
      dispatchNumber: 'DSP-0',
      salesOrderNumber: 'SO-0',
      customer: 'Customer',
      status: 'Loaded',
      loadingBay: 'Bay',
      vehicleRegistration: 'MH00',
      driverName: 'Driver',
      tripNumber: 'TRIP-0',
      packageCount: 0,
      weightKg: 0,
      lines: [],
      checks: [],
    );
    expect(empty.loadedRate, 0);

    const line = DispatchLoadLine(
      sku: 'FG-1',
      name: 'Finished good',
      plannedQuantity: 10,
      loadedQuantity: 20,
      unit: 'pcs',
      ledgerPosted: true,
    );
    expect(line.safeLoadedQuantity, 10);
    expect(line.pendingQuantity, 0);
  });

  test('dispatch finalization requires loaded state, ledger, checks and trip', () {
    DispatchLoadDetail build({
      String status = 'Loaded',
      bool ledger = true,
      bool check = true,
      String trip = 'TRIP-1',
    }) => DispatchLoadDetail(
          dispatchNumber: 'DSP-1',
          salesOrderNumber: 'SO-1',
          customer: 'Customer',
          status: status,
          loadingBay: 'Bay 01',
          vehicleRegistration: 'MH12 AB 4821',
          driverName: 'Driver',
          tripNumber: trip,
          packageCount: 1,
          weightKg: 50,
          lines: [
            DispatchLoadLine(
              sku: 'FG-1',
              name: 'Finished good',
              plannedQuantity: 10,
              loadedQuantity: 10,
              unit: 'pcs',
              ledgerPosted: ledger,
            ),
          ],
          checks: [DispatchRequiredCheck(label: 'Invoice', required: true, complete: check)],
        );

    expect(build().canFinalize, isTrue);
    expect(build(status: 'Dispatched').canFinalize, isFalse);
    expect(build(ledger: false).canFinalize, isFalse);
    expect(build(check: false).canFinalize, isFalse);
    expect(build(trip: '').canFinalize, isFalse);
  });
}
