class SalesOverview {
  const SalesOverview({
    required this.openOrders,
    required this.dueForDispatch,
    required this.paymentPending,
    required this.deliveredThisMonth,
    required this.committedValue,
    required this.orders,
    required this.topCustomers,
    required this.alerts,
  });

  final int openOrders;
  final int dueForDispatch;
  final double paymentPending;
  final int deliveredThisMonth;
  final double committedValue;
  final List<SalesOrderSummary> orders;
  final List<CustomerRevenueSummary> topCustomers;
  final List<SalesAlert> alerts;
}

class SalesOrderSummary {
  const SalesOrderSummary({
    required this.orderNumber,
    required this.customerCode,
    required this.customerName,
    required this.totalValue,
    required this.dispatchDateLabel,
    required this.paymentOutstanding,
    required this.orderStatus,
    required this.deliveryStatus,
  });

  final String orderNumber;
  final String customerCode;
  final String customerName;
  final double totalValue;
  final String dispatchDateLabel;
  final double paymentOutstanding;
  final String orderStatus;
  final String deliveryStatus;

  bool get isPaid => paymentOutstanding <= 0;
}

class CustomerRevenueSummary {
  const CustomerRevenueSummary({required this.customerCode, required this.name, required this.ytdRevenue});
  final String customerCode;
  final String name;
  final double ytdRevenue;
}

class SalesAlert {
  const SalesAlert({required this.title, required this.detail, required this.severity});
  final String title;
  final String detail;
  final SalesAlertSeverity severity;
}

enum SalesAlertSeverity { info, warning, danger }

class CustomerDetail {
  const CustomerDetail({
    required this.customerCode,
    required this.name,
    required this.city,
    required this.state,
    required this.status,
    required this.gstinMasked,
    required this.creditDays,
    required this.creditLimit,
    required this.accountOwner,
    required this.primaryContact,
    required this.phoneMasked,
    required this.emailMasked,
    required this.defaultDelivery,
    required this.ytdSales,
    required this.openOrders,
    required this.outstanding,
    required this.onTimePaymentRate,
    required this.recentOrders,
  });

  final String customerCode;
  final String name;
  final String city;
  final String state;
  final String status;
  final String gstinMasked;
  final int creditDays;
  final double creditLimit;
  final String accountOwner;
  final String primaryContact;
  final String phoneMasked;
  final String emailMasked;
  final String defaultDelivery;
  final double ytdSales;
  final int openOrders;
  final double outstanding;
  final double onTimePaymentRate;
  final List<SalesOrderSummary> recentOrders;

  double get creditUtilization => creditLimit <= 0 ? 0 : outstanding / creditLimit;
}

class SalesOrderLine {
  const SalesOrderLine({required this.sku, required this.itemName, required this.quantity, required this.unit, required this.unitPrice, required this.reservedQuantity});
  final String sku;
  final String itemName;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double reservedQuantity;

  double get lineValue => quantity * unitPrice;
  double get reservationShortage => (quantity - reservedQuantity).clamp(0, double.infinity).toDouble();
}

class SalesOrderDetail {
  const SalesOrderDetail({
    required this.orderNumber,
    required this.customerCode,
    required this.customerName,
    required this.createdDateLabel,
    required this.status,
    required this.customerPo,
    required this.paymentTerms,
    required this.deliveryMethod,
    required this.shipTo,
    required this.dispatchTargetLabel,
    required this.lines,
    required this.amountReceived,
    required this.lifecycle,
  });

  final String orderNumber;
  final String customerCode;
  final String customerName;
  final String createdDateLabel;
  final String status;
  final String customerPo;
  final String paymentTerms;
  final String deliveryMethod;
  final String shipTo;
  final String dispatchTargetLabel;
  final List<SalesOrderLine> lines;
  final double amountReceived;
  final List<SalesLifecycleStep> lifecycle;

  double get totalValue => lines.fold(0, (sum, line) => sum + line.lineValue);
  double get amountOutstanding => (totalValue - amountReceived).clamp(0, double.infinity).toDouble();
  bool get fullyReserved => lines.every((line) => line.reservationShortage == 0);
}

class SalesLifecycleStep {
  const SalesLifecycleStep({required this.label, required this.state});
  final String label;
  final SalesLifecycleState state;
}

enum SalesLifecycleState { complete, current, pending }

class CustomerPayment {
  const CustomerPayment({required this.reference, required this.dateLabel, required this.method, required this.amount, required this.status});
  final String reference;
  final String dateLabel;
  final String method;
  final double amount;
  final String status;
}

class PaymentDeliveryTracking {
  const PaymentDeliveryTracking({
    required this.orderNumber,
    required this.customerName,
    required this.invoiceTotal,
    required this.dueDateLabel,
    required this.payments,
    required this.dispatchTargetLabel,
    required this.dispatchReference,
    required this.vehicleLabel,
    required this.driverName,
    required this.deliveryState,
    required this.deliverySteps,
  });

  final String orderNumber;
  final String customerName;
  final double invoiceTotal;
  final String dueDateLabel;
  final List<CustomerPayment> payments;
  final String dispatchTargetLabel;
  final String dispatchReference;
  final String vehicleLabel;
  final String driverName;
  final String deliveryState;
  final List<SalesLifecycleStep> deliverySteps;

  double get received => payments.where((payment) => payment.status == 'Received').fold(0, (sum, payment) => sum + payment.amount);
  double get outstanding => (invoiceTotal - received).clamp(0, double.infinity).toDouble();
  double get collectionRate => invoiceTotal <= 0 ? 0 : (received / invoiceTotal).clamp(0, 1).toDouble();
}
