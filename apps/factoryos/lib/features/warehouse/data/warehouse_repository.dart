import '../domain/warehouse_models.dart';

class WarehouseOverview {
  const WarehouseOverview({
    required this.receiptsToday,
    required this.issuesToday,
    required this.transfersToday,
    required this.pendingPutaway,
    required this.tasks,
    required this.utilization,
  });

  final int receiptsToday, issuesToday, transfersToday, pendingPutaway;
  final List<WarehouseTask> tasks;
  final List<WarehouseUtilization> utilization;
}

class WarehouseTask {
  const WarehouseTask({
    required this.type,
    required this.reference,
    required this.detail,
    required this.assignee,
    required this.status,
  });

  final String type, reference, detail, assignee, status;
}

class WarehouseUtilization {
  const WarehouseUtilization({required this.name, required this.percent});
  final String name;
  final double percent;
}

abstract interface class WarehouseRepository {
  Future<WarehouseOverview> loadOverview();
  Future<WarehouseTransferDetail> loadTransfer(String transferNumber);
}

final class PreviewWarehouseRepository implements WarehouseRepository {
  const PreviewWarehouseRepository();

  @override
  Future<WarehouseOverview> loadOverview() async => const WarehouseOverview(
        receiptsToday: 18,
        issuesToday: 27,
        transfersToday: 6,
        pendingPutaway: 9,
        tasks: [
          WarehouseTask(
            type: 'Receiving',
            reference: 'GRN-2026-00921',
            detail: 'Apex Steel Supplies • 6 pallets',
            assignee: 'Warehouse Team A',
            status: 'Inspect',
          ),
          WarehouseTask(
            type: 'Putaway',
            reference: 'GRN-2026-00922',
            detail: 'Prime Bearings • 3 cartons',
            assignee: 'Warehouse Team B',
            status: 'Pending',
          ),
          WarehouseTask(
            type: 'Transfer',
            reference: 'TRF-2026-00218',
            detail: 'RM-WH → Production staging',
            assignee: 'Rakesh Jadhav',
            status: 'Ready',
          ),
        ],
        utilization: [
          WarehouseUtilization(name: 'Raw Material', percent: .78),
          WarehouseUtilization(name: 'Finished Goods', percent: .64),
          WarehouseUtilization(name: 'Spares & Consumables', percent: .41),
        ],
      );

  @override
  Future<WarehouseTransferDetail> loadTransfer(String transferNumber) async =>
      const WarehouseTransferDetail(
        transferNumber: 'TRF-2026-00218',
        status: 'Ready',
        sourceWarehouse: 'RM-WH • Raw Material Warehouse',
        destinationWarehouse: 'RM-STAGE-01 • Production staging',
        reason: 'Production material staging',
        assignee: 'Rakesh Jadhav',
        outLedgerPosted: false,
        inLedgerPosted: false,
        lines: [
          WarehouseTransferLine(
            sku: 'RM-STEEL-001',
            name: 'MS Steel Sheet 2mm',
            batchNumber: 'RM-141026-03',
            fromLocation: 'RM-A-R03-B02',
            toLocation: 'RM-STAGE-01',
            quantity: 320,
            unit: 'kg',
          ),
          WarehouseTransferLine(
            sku: 'RM-PIPE-001',
            name: 'Industrial Pipe 25mm',
            batchNumber: 'RM-101026-02',
            fromLocation: 'RM-B-R01-B04',
            toLocation: 'RM-STAGE-01',
            quantity: 160,
            unit: 'pcs',
          ),
          WarehouseTransferLine(
            sku: 'RM-CHEM-001',
            name: 'Production Chemical A',
            batchNumber: 'RM-051026-01',
            fromLocation: 'RM-C-R02-B02',
            toLocation: 'RM-STAGE-01',
            quantity: 100,
            unit: 'L',
          ),
        ],
      );
}
