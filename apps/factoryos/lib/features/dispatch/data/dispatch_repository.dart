import '../domain/dispatch_models.dart';

class DispatchOverview {
  const DispatchOverview({
    required this.readyOrders,
    required this.loadingOrders,
    required this.dispatchedToday,
    required this.blockedOrders,
    required this.orders,
    required this.bays,
    required this.checks,
  });

  final int readyOrders, loadingOrders, dispatchedToday, blockedOrders;
  final List<DispatchOrderSummary> orders;
  final List<LoadingBay> bays;
  final List<DispatchCheck> checks;
}

class DispatchOrderSummary {
  const DispatchOrderSummary({
    required this.orderNumber,
    required this.customer,
    required this.city,
    required this.packages,
    required this.weightKg,
    required this.status,
  });

  final String orderNumber, customer, city, status;
  final int packages;
  final double weightKg;
}

class LoadingBay {
  const LoadingBay({required this.name, required this.vehicle, required this.progress});
  final String name, vehicle;
  final double progress;
}

class DispatchCheck {
  const DispatchCheck({required this.label, required this.complete});
  final String label;
  final bool complete;
}

abstract interface class DispatchRepository {
  Future<DispatchOverview> loadOverview();
  Future<DispatchLoadDetail> loadDispatch(String dispatchNumber);
}

final class PreviewDispatchRepository implements DispatchRepository {
  const PreviewDispatchRepository();

  @override
  Future<DispatchOverview> loadOverview() async => const DispatchOverview(
        readyOrders: 14,
        loadingOrders: 4,
        dispatchedToday: 11,
        blockedOrders: 2,
        orders: [
          DispatchOrderSummary(
            orderNumber: 'DSP-2026-00417',
            customer: 'Sahyadri Process Systems',
            city: 'Pune',
            packages: 24,
            weightKg: 1280,
            status: 'Dispatched',
          ),
          DispatchOrderSummary(
            orderNumber: 'DSP-2026-00418',
            customer: 'Metro Industrial Gases',
            city: 'Nashik',
            packages: 16,
            weightKg: 860,
            status: 'Loading',
          ),
          DispatchOrderSummary(
            orderNumber: 'DSP-2026-00419',
            customer: 'Western Process Systems',
            city: 'Chhatrapati Sambhajinagar',
            packages: 9,
            weightKg: 410,
            status: 'QC blocked',
          ),
        ],
        bays: [
          LoadingBay(name: 'Bay 01', vehicle: 'MH12 AB 4821', progress: 1),
          LoadingBay(name: 'Bay 02', vehicle: 'MH14 KL 7740', progress: .35),
          LoadingBay(name: 'Bay 03', vehicle: 'Available', progress: 0),
        ],
        checks: [
          DispatchCheck(label: 'Invoice generated', complete: true),
          DispatchCheck(label: 'E-way bill validated', complete: true),
          DispatchCheck(label: 'Packing list complete', complete: true),
          DispatchCheck(label: 'Vehicle weight captured', complete: true),
        ],
      );

  @override
  Future<DispatchLoadDetail> loadDispatch(String dispatchNumber) async =>
      const DispatchLoadDetail(
        dispatchNumber: 'DSP-2026-00417',
        salesOrderNumber: 'SO-2026-01842',
        customer: 'Sahyadri Process Systems',
        status: 'Dispatched',
        loadingBay: 'Bay 01',
        vehicleRegistration: 'MH12 AB 4821',
        driverName: 'Amit Shinde',
        tripNumber: 'TRIP-2026-00814',
        packageCount: 24,
        weightKg: 1280,
        lines: [
          DispatchLoadLine(
            sku: 'FG-COMP-X',
            name: 'Industrial Component X',
            batchNumber: 'FG-131026-03',
            plannedQuantity: 80,
            loadedQuantity: 80,
            unit: 'pcs',
            ledgerPosted: true,
          ),
          DispatchLoadLine(
            sku: 'FG-VALVE-25',
            name: 'Valve Assembly 25mm',
            batchNumber: 'FG-141026-04',
            plannedQuantity: 40,
            loadedQuantity: 40,
            unit: 'pcs',
            ledgerPosted: true,
          ),
        ],
        checks: [
          DispatchRequiredCheck(label: 'Invoice generated', required: true, complete: true),
          DispatchRequiredCheck(label: 'E-way bill validated', required: true, complete: true),
          DispatchRequiredCheck(label: 'Packing list complete', required: true, complete: true),
          DispatchRequiredCheck(label: 'Vehicle weight captured', required: true, complete: true),
        ],
      );
}
