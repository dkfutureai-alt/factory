import '../domain/fleet_models.dart';

abstract class FleetRepository {
  Future<FleetOverview> loadOverview();
  Future<VehicleDetail> loadVehicle(String registration);
  Future<DriverDetail> loadDriver(String employeeCode);
  Future<List<TripSummary>> loadTrips();
  Future<FuelOverview> loadFuelOverview();
}

class PreviewFleetRepository implements FleetRepository {
  const PreviewFleetRepository();

  @override
  Future<FleetOverview> loadOverview() async => const FleetOverview(
        totalVehicles: 10,
        activeVehicles: 8,
        tripsToday: 14,
        driversOnDuty: 9,
        fuelSpendMonth: 184230,
        vehicles: [
          VehicleSummary(registration: 'MH 13 DK 4521', type: 'Medium truck', driverName: 'Rahul Jadhav', odometerKm: 84260, status: 'On trip', serviceDueKm: 85000),
          VehicleSummary(registration: 'MH 12 AB 7742', type: 'LCV', driverName: 'Suresh More', odometerKm: 61885, status: 'Available', serviceDueKm: 65000),
          VehicleSummary(registration: 'MH 14 KT 1188', type: 'Pickup', driverName: 'Amit Pawar', odometerKm: 42100, status: 'Service due', serviceDueKm: 42000),
        ],
        alerts: [
          FleetAlert(title: '2 services due', detail: 'Vehicle service required within 7 days', severity: FleetAlertSeverity.warning),
          FleetAlert(title: '1 compliance document expiring', detail: 'PUC review required before dispatch', severity: FleetAlertSeverity.danger),
        ],
      );

  @override
  Future<VehicleDetail> loadVehicle(String registration) async => const VehicleDetail(
        registration: 'MH 13 DK 4521',
        makeModel: 'Tata Ultra T.9',
        capacity: '4.5T',
        fuelType: 'Diesel',
        driverName: 'Rahul Jadhav',
        odometerKm: 84260,
        nextServiceKm: 85000,
        documents: [
          VehicleDocument(label: 'Insurance', value: 'Valid • 28 Feb 2027', isWarning: false),
          VehicleDocument(label: 'Fitness certificate', value: 'Valid • 12 Jan 2027', isWarning: false),
          VehicleDocument(label: 'PUC', value: 'Due • 22 Oct 2026', isWarning: true),
          VehicleDocument(label: 'Permit', value: 'National • Valid', isWarning: false),
        ],
        fuelSpendMonth: 18460,
        maintenanceSpendYear: 42800,
        averageMileageKmPerLitre: 7.8,
        tripsThisMonth: 31,
      );

  @override
  Future<DriverDetail> loadDriver(String employeeCode) async => const DriverDetail(
        employeeCode: 'DRV-0007',
        name: 'Rahul Jadhav',
        designation: 'Heavy transport driver',
        assignedVehicle: 'MH 13 DK 4521',
        dutyStatus: 'On duty',
        licenseClass: 'HMV / Transport',
        licenseValidity: '18 Aug 2029',
        onTimeDeliveryRate: 0.968,
        fuelVarianceRate: -0.021,
        safetyIncidentsYear: 0,
        distanceMonthKm: 3482,
      );

  @override
  Future<List<TripSummary>> loadTrips() async => const [
        TripSummary(tripNumber: 'TRIP-2026-00814', route: 'Plant → CityCare Hospital', vehicleRegistration: 'MH 13 DK 4521', driverName: 'Rahul Jadhav', plannedTime: '10:30', status: 'In progress'),
        TripSummary(tripNumber: 'TRIP-2026-00815', route: 'CityCare → Metro Engineering', vehicleRegistration: 'MH 12 AB 7742', driverName: 'Suresh More', plannedTime: '13:30', status: 'Ready'),
        TripSummary(tripNumber: 'TRIP-2026-00816', route: 'Plant → Nashik Automation', vehicleRegistration: 'MH 14 KT 1188', driverName: 'Amit Pawar', plannedTime: '15:00', status: 'Vehicle hold'),
      ];

  @override
  Future<FuelOverview> loadFuelOverview() async => const FuelOverview(
        totalLitresMonth: 1842,
        spendMonth: 184230,
        targetMileageKmPerLitre: 7.2,
        entries: [
          FuelEntrySummary(entryNumber: 'FUEL-01472', vehicleRegistration: 'MH 13 DK 4521', driverName: 'Rahul Jadhav', odometerKm: 84260, litres: 38.2, amount: 3780, distanceSincePreviousKm: 302, reviewStatus: 'OK'),
          FuelEntrySummary(entryNumber: 'FUEL-01471', vehicleRegistration: 'MH 12 AB 7742', driverName: 'Suresh More', odometerKm: 61885, litres: 31, amount: 3068, distanceSincePreviousKm: 180, reviewStatus: 'Review'),
          FuelEntrySummary(entryNumber: 'FUEL-01470', vehicleRegistration: 'MH 14 KT 1188', driverName: 'Amit Pawar', odometerKm: 42100, litres: 22.5, amount: 2228, distanceSincePreviousKm: 205, reviewStatus: 'OK'),
        ],
      );
}
