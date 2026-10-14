import 'package:factoryos/features/fleet/domain/fleet_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fleet availability handles normal and zero vehicle counts', () {
    const normal = FleetOverview(totalVehicles: 10, activeVehicles: 8, tripsToday: 0, driversOnDuty: 0, fuelSpendMonth: 0, vehicles: [], alerts: []);
    const zero = FleetOverview(totalVehicles: 0, activeVehicles: 0, tripsToday: 0, driversOnDuty: 0, fuelSpendMonth: 0, vehicles: [], alerts: []);
    expect(normal.availabilityRate, 0.8);
    expect(zero.availabilityRate, 0);
  });

  test('vehicle service remaining never goes negative', () {
    const due = VehicleSummary(registration: 'X', type: 'Truck', driverName: 'Demo', odometerKm: 42100, status: 'Service due', serviceDueKm: 42000);
    const future = VehicleSummary(registration: 'Y', type: 'Truck', driverName: 'Demo', odometerKm: 40000, status: 'Available', serviceDueKm: 42000);
    expect(due.serviceRemainingKm, 0);
    expect(due.serviceDue, isTrue);
    expect(future.serviceRemainingKm, 2000);
    expect(future.serviceDue, isFalse);
  });

  test('fuel mileage and variance alerts are derived safely', () {
    const low = FuelEntrySummary(entryNumber: '1', vehicleRegistration: 'A', driverName: 'D', odometerKm: 100, litres: 20, amount: 1000, distanceSincePreviousKm: 100, reviewStatus: 'Review');
    const good = FuelEntrySummary(entryNumber: '2', vehicleRegistration: 'B', driverName: 'E', odometerKm: 200, litres: 20, amount: 1000, distanceSincePreviousKm: 180, reviewStatus: 'OK');
    const overview = FuelOverview(totalLitresMonth: 40, spendMonth: 2000, entries: [low, good], targetMileageKmPerLitre: 7.2);
    expect(low.mileageKmPerLitre, 5);
    expect(good.mileageKmPerLitre, 9);
    expect(overview.fleetMileageKmPerLitre, 7);
    expect(overview.varianceAlerts, 1);

    const noFuel = FuelEntrySummary(entryNumber: '3', vehicleRegistration: 'C', driverName: 'F', odometerKm: 0, litres: 0, amount: 0, distanceSincePreviousKm: 0, reviewStatus: 'OK');
    expect(noFuel.mileageKmPerLitre, 0);
  });
}
