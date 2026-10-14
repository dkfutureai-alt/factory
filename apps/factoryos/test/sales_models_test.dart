import 'package:factoryos/features/sales/domain/sales_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sales order outstanding and reservation shortage never go negative', () {
    const detail = SalesOrderDetail(
      orderNumber: 'SO-TEST',
      customerCode: 'CUST-TEST',
      customerName: 'Demo Customer',
      createdDateLabel: '14 Oct 2026',
      status: 'Ready',
      customerPo: 'PO-1',
      paymentTerms: '30 days',
      deliveryMethod: 'Company vehicle',
      shipTo: 'Demo address',
      dispatchTargetLabel: '16 Oct 2026',
      amountReceived: 500,
      lines: [SalesOrderLine(sku: 'FG-1', itemName: 'Finished Good', quantity: 10, unit: 'pcs', unitPrice: 40, reservedQuantity: 12)],
      lifecycle: [],
    );

    expect(detail.totalValue, 400);
    expect(detail.amountOutstanding, 0);
    expect(detail.lines.single.reservationShortage, 0);
    expect(detail.fullyReserved, isTrue);
  });

  test('payment tracking derives received outstanding and bounded collection rate', () {
    const tracking = PaymentDeliveryTracking(
      orderNumber: 'SO-TEST',
      customerName: 'Demo Customer',
      invoiceTotal: 1000,
      dueDateLabel: '30 Oct 2026',
      payments: [
        CustomerPayment(reference: 'PAY-1', dateLabel: '14 Oct', method: 'Bank', amount: 600, status: 'Received'),
        CustomerPayment(reference: 'PAY-2', dateLabel: '14 Oct', method: 'Bank', amount: 600, status: 'Received'),
        CustomerPayment(reference: 'PAY-X', dateLabel: '14 Oct', method: 'Bank', amount: 200, status: 'Reversed'),
      ],
      dispatchTargetLabel: '16 Oct',
      dispatchReference: 'DSP-1',
      vehicleLabel: 'Vehicle',
      driverName: 'Driver',
      deliveryState: 'Scheduled',
      deliverySteps: [],
    );

    expect(tracking.received, 1200);
    expect(tracking.outstanding, 0);
    expect(tracking.collectionRate, 1);
  });

  test('customer credit utilization handles zero credit limit', () {
    const customer = CustomerDetail(
      customerCode: 'CUST-1',
      name: 'Customer',
      city: 'Pune',
      state: 'Maharashtra',
      status: 'Active',
      gstinMasked: 'masked',
      creditDays: 0,
      creditLimit: 0,
      accountOwner: 'Owner',
      primaryContact: 'Desk',
      phoneMasked: 'masked',
      emailMasked: 'masked',
      defaultDelivery: 'Address',
      ytdSales: 0,
      openOrders: 0,
      outstanding: 100,
      onTimePaymentRate: 0,
      recentOrders: [],
    );

    expect(customer.creditUtilization, 0);
  });
}
