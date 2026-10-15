import 'package:factoryos/features/delivery/domain/delivery_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('delivery line pending quantity never goes negative', () {
    const line = DeliveryLine(itemCode: 'FG-X', itemName: 'X', plannedQuantity: 10, acceptedQuantity: 9, rejectedQuantity: 4);
    expect(line.pendingQuantity, 0);
  });

  test('delivery completion requires reconciliation receiver and evidence', () {
    const ready = DeliveryDetail(
      deliveryNumber: 'D1', customer: 'C', salesOrderNumber: 'SO1', tripNumber: 'T1', shipTo: 'A',
      driverName: 'D', driverCode: 'DRV', vehicleRegistration: 'V', etaLabel: 'ETA', status: 'Arrived', podStatus: 'Captured',
      receiverName: 'Receiver', deliveredAtLabel: 'Now', hasPodEvidence: true,
      lines: [DeliveryLine(itemCode: 'I', itemName: 'Item', plannedQuantity: 10, acceptedQuantity: 8, rejectedQuantity: 2, rejectionReason: 'Damage')],
    );
    const blocked = DeliveryDetail(
      deliveryNumber: 'D2', customer: 'C', salesOrderNumber: 'SO2', tripNumber: 'T2', shipTo: 'A',
      driverName: 'D', driverCode: 'DRV', vehicleRegistration: 'V', etaLabel: 'ETA', status: 'In transit', podStatus: 'Pending',
      receiverName: '', deliveredAtLabel: 'Pending', hasPodEvidence: false,
      lines: [DeliveryLine(itemCode: 'I', itemName: 'Item', plannedQuantity: 10, acceptedQuantity: 0, rejectedQuantity: 0)],
    );
    expect(ready.canComplete, isTrue);
    expect(blocked.canComplete, isFalse);
    expect(blocked.pendingQuantity, 10);
  });

  test('delivery exception derives physical return need', () {
    const exception = DeliveryExceptionDetail(
      deliveryNumber: 'D', customer: 'C', exceptionType: 'Partial rejection', customerNote: 'Damaged', evidenceCount: 1,
      returnTripNumber: 'Pending', resolutionStatus: 'Pending',
      lines: [DeliveryLine(itemCode: 'I', itemName: 'Item', plannedQuantity: 10, acceptedQuantity: 7, rejectedQuantity: 3, rejectionReason: 'Damage')],
    );
    expect(exception.rejectedQuantity, 3);
    expect(exception.requiresReturn, isTrue);
  });
}
