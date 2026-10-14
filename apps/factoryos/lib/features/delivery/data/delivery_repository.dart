import '../domain/delivery_models.dart';

abstract class DeliveryRepository {
  Future<DeliveryOverview> loadOverview();
  Future<DeliveryDetail> loadDelivery(String deliveryNumber);
  Future<DeliveryExceptionDetail> loadException(String deliveryNumber);
}

class PreviewDeliveryRepository implements DeliveryRepository {
  const PreviewDeliveryRepository();

  @override
  Future<DeliveryOverview> loadOverview() async => const DeliveryOverview(
        outForDelivery: 8,
        deliveredToday: 12,
        podPending: 3,
        exceptions: 2,
        deliveries: [
          DeliverySummary(deliveryNumber: 'DEL-2026-00681', customer: 'CityCare Hospital', salesOrderNumber: 'SO-2026-01842', tripNumber: 'TRIP-2026-00814', etaLabel: '11:20 AM', status: 'In transit', podStatus: 'Pending'),
          DeliverySummary(deliveryNumber: 'DEL-2026-00682', customer: 'Metro Engineering', salesOrderNumber: 'SO-2026-01843', tripNumber: 'TRIP-2026-00815', etaLabel: '02:15 PM', status: 'Arrived', podStatus: 'Pending'),
          DeliverySummary(deliveryNumber: 'DEL-2026-00679', customer: 'Sunrise Fabrication', salesOrderNumber: 'SO-2026-01839', tripNumber: 'TRIP-2026-00811', etaLabel: '09:05 AM', status: 'Delivered', podStatus: 'Verified'),
          DeliverySummary(deliveryNumber: 'DEL-2026-00678', customer: 'Apex Process Systems', salesOrderNumber: 'SO-2026-01838', tripNumber: 'TRIP-2026-00810', etaLabel: '08:40 AM', status: 'Rejected qty', podStatus: 'Captured'),
        ],
        alerts: [
          DeliveryAlert(title: '3 PODs pending', detail: 'Driver/customer confirmation required', severity: DeliveryAlertSeverity.warning),
          DeliveryAlert(title: '2 delivery exceptions', detail: 'Short or rejected quantity requires review', severity: DeliveryAlertSeverity.danger),
        ],
      );

  @override
  Future<DeliveryDetail> loadDelivery(String deliveryNumber) async {
    if (deliveryNumber == 'DEL-2026-00678') {
      return const DeliveryDetail(
        deliveryNumber: 'DEL-2026-00678',
        customer: 'Apex Process Systems',
        salesOrderNumber: 'SO-2026-01838',
        tripNumber: 'TRIP-2026-00810',
        shipTo: 'Apex Process Systems, MIDC Industrial Area, Pune',
        driverName: 'Amit Pawar',
        driverCode: 'DRV-0003',
        vehicleRegistration: 'MH 14 KT 1188',
        etaLabel: '14 Oct 2026 • 08:40 AM',
        status: 'Exception',
        podStatus: 'Captured',
        receiverName: 'S. Kulkarni',
        deliveredAtLabel: '14 Oct 2026 • 08:46 AM',
        hasPodEvidence: true,
        lines: [
          DeliveryLine(itemCode: 'FG-VALVE-25', itemName: 'Valve Assembly 25mm', plannedQuantity: 40, acceptedQuantity: 32, rejectedQuantity: 8, rejectionReason: 'Packaging damage'),
        ],
      );
    }

    return const DeliveryDetail(
      deliveryNumber: 'DEL-2026-00681',
      customer: 'CityCare Hospital',
      salesOrderNumber: 'SO-2026-01842',
      tripNumber: 'TRIP-2026-00814',
      shipTo: 'CityCare Hospital, Industrial Area, Pune',
      driverName: 'Rahul Jadhav',
      driverCode: 'DRV-0001',
      vehicleRegistration: 'MH 13 DK 4521',
      etaLabel: '14 Oct 2026 • 11:20 AM',
      status: 'In transit',
      podStatus: 'Pending',
      receiverName: '',
      deliveredAtLabel: 'Pending',
      hasPodEvidence: false,
      lines: [
        DeliveryLine(itemCode: 'FG-COMP-X', itemName: 'Industrial Component X', plannedQuantity: 80, acceptedQuantity: 0, rejectedQuantity: 0),
        DeliveryLine(itemCode: 'FG-VALVE-25', itemName: 'Valve Assembly 25mm', plannedQuantity: 40, acceptedQuantity: 0, rejectedQuantity: 0),
      ],
    );
  }

  @override
  Future<DeliveryExceptionDetail> loadException(String deliveryNumber) async => const DeliveryExceptionDetail(
        deliveryNumber: 'DEL-2026-00678',
        customer: 'Apex Process Systems',
        exceptionType: 'Partial rejection',
        customerNote: 'Eight cartons damaged during unloading; return requested.',
        evidenceCount: 2,
        returnTripNumber: 'Not created',
        resolutionStatus: 'Pending',
        lines: [
          DeliveryLine(itemCode: 'FG-VALVE-25', itemName: 'Valve Assembly 25mm', plannedQuantity: 40, acceptedQuantity: 32, rejectedQuantity: 8, rejectionReason: 'Packaging damage'),
        ],
      );
}
