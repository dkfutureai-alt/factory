import 'package:flutter/material.dart';
import 'factoryos_exports.dart';
class FactoryOsFleetRoutes {
 static final Map<String, WidgetBuilder> routes = {
 '/fleet': (_) => const FleetDashboardPage(repository: PreviewFleetRepository()),
 '/fleet/vehicle': (_) => const VehicleDetailPage(repository: PreviewFleetRepository(), registration: 'VEH-001'),
 '/fleet/driver': (_) => const DriverDetailPage(repository: PreviewFleetRepository(), employeeCode: 'DRV-0001'),
 '/fleet/trips': (_) => const TripManagementPage(repository: PreviewFleetRepository()),
 '/fleet/fuel': (_) => const FuelManagementPage(repository: PreviewFleetRepository()),
 '/delivery/driver': (_) => const DeliveryDetailPage(repository: PreviewDeliveryRepository(), deliveryNumber: 'DEL-2026-00681', driverMode: true),
 };
}
