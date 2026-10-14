import '../domain/sales_models.dart';

abstract interface class SalesRepository {
  Future<SalesOverview> loadOverview();
  Future<CustomerDetail> loadCustomer(String customerCode);
  Future<SalesOrderDetail> loadOrder(String orderNumber);
  Future<PaymentDeliveryTracking> loadTracking(String orderNumber);
}

final class PreviewSalesRepository implements SalesRepository {
  const PreviewSalesRepository();

  static const _orders = [
    SalesOrderSummary(orderNumber: 'SO-2026-01842', customerCode: 'CUST-0042', customerName: 'Sahyadri Process Systems', totalValue: 486000, dispatchDateLabel: '16 Oct', paymentOutstanding: 200000, orderStatus: 'Ready', deliveryStatus: 'Scheduled'),
    SalesOrderSummary(orderNumber: 'SO-2026-01843', customerCode: 'CUST-0031', customerName: 'Apex Hospital Engineering', totalValue: 312000, dispatchDateLabel: '17 Oct', paymentOutstanding: 0, orderStatus: 'Production', deliveryStatus: 'Pending'),
    SalesOrderSummary(orderNumber: 'SO-2026-01839', customerCode: 'CUST-0018', customerName: 'Western Industrial Gases', totalValue: 640000, dispatchDateLabel: '14 Oct', paymentOutstanding: 140000, orderStatus: 'Dispatched', deliveryStatus: 'In transit'),
    SalesOrderSummary(orderNumber: 'SO-2026-01836', customerCode: 'CUST-0026', customerName: 'Nashik Automation Works', totalValue: 276000, dispatchDateLabel: '12 Oct', paymentOutstanding: 0, orderStatus: 'Delivered', deliveryStatus: 'Delivered'),
  ];

  @override
  Future<SalesOverview> loadOverview() async => const SalesOverview(
        openOrders: 18,
        dueForDispatch: 7,
        paymentPending: 860000,
        deliveredThisMonth: 42,
        committedValue: 2480000,
        orders: _orders,
        topCustomers: [
          CustomerRevenueSummary(customerCode: 'CUST-0042', name: 'Sahyadri Process Systems', ytdRevenue: 1840000),
          CustomerRevenueSummary(customerCode: 'CUST-0018', name: 'Western Industrial Gases', ytdRevenue: 1590000),
          CustomerRevenueSummary(customerCode: 'CUST-0031', name: 'Apex Hospital Engineering', ytdRevenue: 1210000),
        ],
        alerts: [
          SalesAlert(title: '2 overdue customer payments', detail: '₹2.10L total outstanding beyond due date', severity: SalesAlertSeverity.danger),
          SalesAlert(title: '3 orders awaiting credit approval', detail: 'Sales Manager / Finance action required', severity: SalesAlertSeverity.warning),
          SalesAlert(title: '7 dispatches scheduled in 72 hours', detail: 'Coordinate finished goods and transport readiness', severity: SalesAlertSeverity.info),
        ],
      );

  @override
  Future<CustomerDetail> loadCustomer(String customerCode) async => CustomerDetail(
        customerCode: 'CUST-0042',
        name: 'Sahyadri Process Systems',
        city: 'Pune',
        state: 'Maharashtra',
        status: 'Active',
        gstinMasked: '27AAECS••••A1Z•',
        creditDays: 30,
        creditLimit: 1000000,
        accountOwner: 'Neha Joshi',
        primaryContact: 'Procurement Desk',
        phoneMasked: '98••• ••421',
        emailMasked: 'pro••••••@example.test',
        defaultDelivery: 'Chakan Industrial Area',
        ytdSales: 1840000,
        openOrders: 3,
        outstanding: 200000,
        onTimePaymentRate: .92,
        recentOrders: const [
          SalesOrderSummary(orderNumber: 'SO-2026-01842', customerCode: 'CUST-0042', customerName: 'Sahyadri Process Systems', totalValue: 486000, dispatchDateLabel: '16 Oct', paymentOutstanding: 200000, orderStatus: 'Ready', deliveryStatus: 'Scheduled'),
          SalesOrderSummary(orderNumber: 'SO-2026-01791', customerCode: 'CUST-0042', customerName: 'Sahyadri Process Systems', totalValue: 322000, dispatchDateLabel: '30 Sep', paymentOutstanding: 0, orderStatus: 'Closed', deliveryStatus: 'Delivered'),
          SalesOrderSummary(orderNumber: 'SO-2026-01724', customerCode: 'CUST-0042', customerName: 'Sahyadri Process Systems', totalValue: 295000, dispatchDateLabel: '12 Sep', paymentOutstanding: 0, orderStatus: 'Closed', deliveryStatus: 'Delivered'),
        ],
      );

  @override
  Future<SalesOrderDetail> loadOrder(String orderNumber) async => const SalesOrderDetail(
        orderNumber: 'SO-2026-01842',
        customerCode: 'CUST-0042',
        customerName: 'Sahyadri Process Systems',
        createdDateLabel: '14 Oct 2026',
        status: 'Ready',
        customerPo: 'SPS/PO/2287',
        paymentTerms: '30 days',
        deliveryMethod: 'Company vehicle',
        shipTo: 'Chakan Industrial Area',
        dispatchTargetLabel: '16 Oct 2026',
        amountReceived: 286000,
        lines: [
          SalesOrderLine(sku: 'FG-COMP-X', itemName: 'Industrial Component X', quantity: 120, unit: 'pcs', unitPrice: 2850, reservedQuantity: 120),
          SalesOrderLine(sku: 'FG-VALVE-25', itemName: 'Valve Assembly 25mm', quantity: 80, unit: 'pcs', unitPrice: 1800, reservedQuantity: 80),
        ],
        lifecycle: [
          SalesLifecycleStep(label: 'Confirmed', state: SalesLifecycleState.complete),
          SalesLifecycleStep(label: 'Production', state: SalesLifecycleState.complete),
          SalesLifecycleStep(label: 'QC released', state: SalesLifecycleState.complete),
          SalesLifecycleStep(label: 'Ready', state: SalesLifecycleState.current),
          SalesLifecycleStep(label: 'Dispatched', state: SalesLifecycleState.pending),
          SalesLifecycleStep(label: 'Delivered', state: SalesLifecycleState.pending),
        ],
      );

  @override
  Future<PaymentDeliveryTracking> loadTracking(String orderNumber) async => const PaymentDeliveryTracking(
        orderNumber: 'SO-2026-01842',
        customerName: 'Sahyadri Process Systems',
        invoiceTotal: 486000,
        dueDateLabel: '13 Nov 2026',
        payments: [
          CustomerPayment(reference: 'PAY-2026-01182', dateLabel: '14 Oct 2026', method: 'Bank transfer', amount: 200000, status: 'Received'),
          CustomerPayment(reference: 'PAY-2026-01174', dateLabel: '10 Oct 2026', method: 'Bank transfer', amount: 86000, status: 'Received'),
        ],
        dispatchTargetLabel: '16 Oct 2026',
        dispatchReference: 'DSP-2026-00912',
        vehicleLabel: 'MH 12 AB 4821',
        driverName: 'Suresh Jadhav',
        deliveryState: 'Scheduled',
        deliverySteps: [
          SalesLifecycleStep(label: 'Ready', state: SalesLifecycleState.complete),
          SalesLifecycleStep(label: 'Scheduled', state: SalesLifecycleState.current),
          SalesLifecycleStep(label: 'Loaded', state: SalesLifecycleState.pending),
          SalesLifecycleStep(label: 'In transit', state: SalesLifecycleState.pending),
          SalesLifecycleStep(label: 'Delivered', state: SalesLifecycleState.pending),
        ],
      );
}
