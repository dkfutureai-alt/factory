enum FleetAlertSeverity { info, warning, danger }

class FleetOverview {
  const FleetOverview({required this.totalVehicles, required this.activeVehicles, required this.tripsToday, required this.driversOnDuty, required this.fuelSpendMonth, required this.vehicles, required this.alerts});
  final int totalVehicles;
  final int activeVehicles;
  final int tripsToday;
  final int driversOnDuty;
  final double fuelSpendMonth;
  final List<VehicleSummary> vehicles;
  final List<FleetAlert> alerts;

  double get availabilityRate => totalVehicles == 0 ? 0 : activeVehicles / totalVehicles;
}

class VehicleSummary {
  const VehicleSummary({required this.registration, required this.type, required this.driverName, required this.odometerKm, required this.status, required this.serviceDueKm});
  final String registration;
  final String type;
  final String driverName;
  final int odometerKm;
  final String status;
  final int serviceDueKm;

  int get serviceRemainingKm => (serviceDueKm - odometerKm).clamp(0, 1 << 30).toInt();
  bool get serviceDue => odometerKm >= serviceDueKm;
}

class FleetAlert {
  const FleetAlert({required this.title, required this.detail, required this.severity});
  final String title;
  final String detail;
  final FleetAlertSeverity severity;
}

class VehicleDetail {
  const VehicleDetail({required this.registration, required this.makeModel, required this.capacity, required this.fuelType, required this.driverName, required this.odometerKm, required this.nextServiceKm, required this.documents, required this.fuelSpendMonth, required this.maintenanceSpendYear, required this.averageMileageKmPerLitre, required this.tripsThisMonth});
  final String registration;
  final String makeModel;
  final String capacity;
  final String fuelType;
  final String driverName;
  final int odometerKm;
  final int nextServiceKm;
  final List<VehicleDocument> documents;
  final double fuelSpendMonth;
  final double maintenanceSpendYear;
  final double averageMileageKmPerLitre;
  final int tripsThisMonth;
}

class VehicleDocument {
  const VehicleDocument({required this.label, required this.value, required this.isWarning});
  final String label;
  final String value;
  final bool isWarning;
}

class DriverDetail {
  const DriverDetail({required this.employeeCode, required this.name, required this.designation, required this.assignedVehicle, required this.dutyStatus, required this.licenseClass, required this.licenseValidity, required this.onTimeDeliveryRate, required this.fuelVarianceRate, required this.safetyIncidentsYear, required this.distanceMonthKm});
  final String employeeCode;
  final String name;
  final String designation;
  final String assignedVehicle;
  final String dutyStatus;
  final String licenseClass;
  final String licenseValidity;
  final double onTimeDeliveryRate;
  final double fuelVarianceRate;
  final int safetyIncidentsYear;
  final int distanceMonthKm;
}

class TripSummary {
  const TripSummary({required this.tripNumber, required this.route, required this.vehicleRegistration, required this.driverName, required this.plannedTime, required this.status});
  final String tripNumber;
  final String route;
  final String vehicleRegistration;
  final String driverName;
  final String plannedTime;
  final String status;
}

class FuelEntrySummary {
  const FuelEntrySummary({required this.entryNumber, required this.vehicleRegistration, required this.driverName, required this.odometerKm, required this.litres, required this.amount, required this.distanceSincePreviousKm, required this.reviewStatus});
  final String entryNumber;
  final String vehicleRegistration;
  final String driverName;
  final int odometerKm;
  final double litres;
  final double amount;
  final int distanceSincePreviousKm;
  final String reviewStatus;

  double get mileageKmPerLitre => litres <= 0 ? 0 : distanceSincePreviousKm / litres;
}

class FuelOverview {
  const FuelOverview({required this.totalLitresMonth, required this.spendMonth, required this.entries, required this.targetMileageKmPerLitre});
  final double totalLitresMonth;
  final double spendMonth;
  final List<FuelEntrySummary> entries;
  final double targetMileageKmPerLitre;

  double get fleetMileageKmPerLitre {
    final litres = entries.fold<double>(0, (sum, entry) => sum + entry.litres);
    final distance = entries.fold<int>(0, (sum, entry) => sum + entry.distanceSincePreviousKm);
    return litres <= 0 ? 0 : distance / litres;
  }

  int get varianceAlerts => entries.where((entry) => entry.mileageKmPerLitre < targetMileageKmPerLitre * 0.85).length;
}
