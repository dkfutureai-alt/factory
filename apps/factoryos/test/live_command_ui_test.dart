import 'package:factoryos/features/dispatch/data/dispatch_repository.dart';
import 'package:factoryos/features/dispatch/domain/dispatch_models.dart';
import 'package:factoryos/features/dispatch/presentation/dispatch_load_detail_page.dart';
import 'package:factoryos/features/warehouse/data/warehouse_repository.dart';
import 'package:factoryos/features/warehouse/domain/warehouse_models.dart';
import 'package:factoryos/features/warehouse/presentation/warehouse_transfer_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('live Warehouse repository enables atomic transfer command', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _LiveWarehouseFake();

    await tester.pumpWidget(MaterialApp(
      home: WarehouseTransferDetailPage(repository: repository, transferNumber: 'TRF-LIVE-001'),
    ));
    await tester.pumpAndSettle();

    final button = find.widgetWithText(FilledButton, 'Complete transfer');
    expect(button, findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(repository.completeCalls, 1);
    expect(find.widgetWithText(FilledButton, 'Transfer completed'), findsOneWidget);
    expect(find.text('Posted'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('live Dispatch follows full load to stock post to finalization', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _LiveDispatchFake();

    await tester.pumpWidget(MaterialApp(
      routes: {
        '/delivery': (_) => const Scaffold(body: Text('Delivery queue')),
        '/delivery/detail': (_) => const Scaffold(body: Text('Delivery detail')),
      },
      home: DispatchLoadDetailPage(repository: repository, dispatchNumber: 'DSP-LIVE-001'),
    ));
    await tester.pumpAndSettle();

    final postButton = find.widgetWithText(FilledButton, 'Post dispatch stock');
    expect(postButton, findsOneWidget);
    await tester.tap(postButton);
    await tester.pumpAndSettle();

    expect(repository.postCalls, 1);
    final finalizeButton = find.widgetWithText(FilledButton, 'Finalize dispatch');
    expect(finalizeButton, findsOneWidget);
    await tester.tap(finalizeButton);
    await tester.pumpAndSettle();

    expect(repository.finalizeCalls, 1);
    expect(find.widgetWithText(FilledButton, 'Open Delivery handoff'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _LiveWarehouseFake implements WarehouseRepository {
  int completeCalls = 0;
  bool completed = false;

  @override
  bool get supportsMutations => true;

  WarehouseTransferDetail get _detail => WarehouseTransferDetail(
        transferNumber: 'TRF-LIVE-001',
        status: completed ? 'Completed' : 'Ready',
        sourceWarehouse: 'RM-WH',
        destinationWarehouse: 'RM-STAGE-01',
        reason: 'Production staging',
        assignee: 'Warehouse Manager',
        outLedgerPosted: completed,
        inLedgerPosted: completed,
        lines: const [
          WarehouseTransferLine(
            sku: 'RM-1',
            name: 'Raw material',
            fromLocation: 'A-01',
            toLocation: 'STAGE-01',
            quantity: 10,
            unit: 'pcs',
          ),
        ],
      );

  @override
  Future<WarehouseTransferDetail> completeTransfer(String transferNumber) async {
    completeCalls++;
    completed = true;
    return _detail;
  }

  @override
  Future<WarehouseTransferDetail> loadTransfer(String transferNumber) async => _detail;

  @override
  Future<WarehouseOverview> loadOverview() async => const WarehouseOverview(
        receiptsToday: 0,
        issuesToday: 0,
        transfersToday: 1,
        pendingPutaway: 0,
        tasks: [],
        utilization: [],
      );
}

class _LiveDispatchFake implements DispatchRepository {
  int postCalls = 0;
  int finalizeCalls = 0;
  String status = 'Ready';
  bool ledgerPosted = false;

  @override
  bool get supportsMutations => true;

  DispatchLoadDetail get _detail => DispatchLoadDetail(
        dispatchNumber: 'DSP-LIVE-001',
        salesOrderNumber: 'SO-LIVE-001',
        customer: 'Test Customer',
        status: status,
        loadingBay: 'Bay 01',
        vehicleRegistration: 'MH 12 TEST 01',
        driverName: 'Test Driver',
        tripNumber: 'TRIP-LIVE-001',
        packageCount: 1,
        weightKg: 10,
        lines: [
          DispatchLoadLine(
            sku: 'FG-1',
            name: 'Finished good',
            plannedQuantity: 10,
            loadedQuantity: 10,
            unit: 'pcs',
            ledgerPosted: ledgerPosted,
          ),
        ],
        checks: const [
          DispatchRequiredCheck(label: 'Invoice generated', required: true, complete: true),
          DispatchRequiredCheck(label: 'Vehicle weight captured', required: true, complete: true),
        ],
      );

  @override
  Future<DispatchLoadDetail> postStock(String dispatchNumber) async {
    postCalls++;
    ledgerPosted = true;
    status = 'Loaded';
    return _detail;
  }

  @override
  Future<DispatchLoadDetail> finalizeDispatch(String dispatchNumber) async {
    finalizeCalls++;
    status = 'Dispatched';
    return _detail;
  }

  @override
  Future<DispatchLoadDetail> loadDispatch(String dispatchNumber) async => _detail;

  @override
  Future<DispatchOverview> loadOverview() async => const DispatchOverview(
        readyOrders: 1,
        loadingOrders: 0,
        dispatchedToday: 0,
        blockedOrders: 0,
        orders: [],
        bays: [],
        checks: [],
      );
}
