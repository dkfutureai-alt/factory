import 'package:factoryos/factoryos_exports.dart';
import 'package:factoryos/features/inventory/domain/inventory_stock_entry_models.dart';
import 'package:factoryos/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Stock Entry request signs quantities and enforces tracking', () async {
    final options = await const PreviewInventoryStockEntryRepository().loadOptions();
    final stockOut = InventoryStockEntryRequest(
      direction: InventoryStockEntryDirection.stockOut,
      warehouseId: 'preview-rm-wh',
      locationId: 'preview-rm-a',
      itemId: 'preview-pk-carton',
      quantity: 5,
      unitCost: 22,
      reason: 'Approved count correction',
      idempotencyKey: 'test-stock-entry-001',
    );
    expect(stockOut.quantityDelta, -5);
    expect(stockOut.validate(options), isNull);

    final missingBatch = InventoryStockEntryRequest(
      direction: InventoryStockEntryDirection.stockIn,
      warehouseId: 'preview-rm-wh',
      locationId: 'preview-rm-a',
      itemId: 'preview-rm-steel',
      quantity: 10,
      unitCost: 72.5,
      reason: 'Approved count correction',
      idempotencyKey: 'test-stock-entry-002',
    );
    expect(missingBatch.validate(options), contains('Select a batch'));
  });

  test('Preview Stock Entry never performs a fake mutation', () async {
    const repository = PreviewInventoryStockEntryRepository();
    final options = await repository.loadOptions();
    expect(repository.supportsPosting, isFalse);
    expect(
      () => repository.postAdjustment(
        InventoryStockEntryRequest(
          direction: InventoryStockEntryDirection.stockIn,
          warehouseId: 'preview-rm-wh',
          locationId: 'preview-rm-a',
          itemId: 'preview-pk-carton',
          quantity: 1,
          unitCost: 22,
          reason: 'Approved count correction',
          idempotencyKey: 'test-stock-entry-preview',
        ),
      ),
      throwsA(isA<UnsupportedError>()),
    );
    expect(options.quantityAt(itemId: 'preview-pk-carton', warehouseId: 'preview-rm-wh', locationId: 'preview-rm-a'), 860);
  });

  testWidgets('Inventory dashboard opens Stock Entry preview workflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const FactoryOsApp(initialRoute: '/inventory'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Stock entry'));
    await tester.pumpAndSettle();

    expect(find.text('Inventory Stock Entry'), findsOneWidget);
    expect(find.textContaining('Preview mode'), findsWidgets);
    expect(find.text('Post stock entry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('live-capable Stock Entry posts through repository boundary', (tester) async {
    final repository = _FakeStockEntryRepository();
    await tester.binding.setSurfaceSize(const Size(1440, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: InventoryStockEntryPage(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), '25');
    await tester.enterText(textFields.at(2), 'Approved physical count correction');
    await tester.tap(find.text('Post stock entry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(repository.postCount, 1);
    expect(repository.lastRequest?.quantityDelta, 25);
    expect(repository.lastRequest?.reason, 'Approved physical count correction');
    expect(find.textContaining('ADJ-TEST-001'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

final class _FakeStockEntryRepository implements InventoryStockEntryRepository {
  int postCount = 0;
  InventoryStockEntryRequest? lastRequest;

  @override
  bool get supportsPosting => true;

  @override
  Future<InventoryStockEntryOptions> loadOptions() async => const PreviewInventoryStockEntryRepository().loadOptions();

  @override
  Future<InventoryStockEntryResult> postAdjustment(InventoryStockEntryRequest request) async {
    postCount++;
    lastRequest = request;
    return const InventoryStockEntryResult(
      transactionId: 'tx-test-001',
      transactionNumber: 'ADJ-TEST-001',
      status: 'posted',
    );
  }
}
