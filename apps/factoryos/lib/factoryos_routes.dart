import 'package:flutter/material.dart';

import 'core/backend/factoryos_services.dart';
import 'factoryos_exports.dart';
import 'factoryos_routes_fleet.dart';
import 'factoryos_routes_operations.dart';
import 'factoryos_routes_people.dart';

class FactoryOsRoutes {
  static final Map<String, WidgetBuilder> routes = {
    ...FactoryOsOperationsRoutes.routes,
    ...FactoryOsPeopleRoutes.routes,
    ...FactoryOsFleetRoutes.routes,
  };

  static Map<String, WidgetBuilder> forServices(FactoryOsServices services) => {
        ...routes,
        '/': (_) => LoginPage(
              repository: services.authRepository,
              connectionLabel: services.config.connectionLabel,
            ),
        '/warehouse': (_) => WarehouseDashboardPage(repository: services.warehouseRepository),
        '/warehouse/transfer': (_) => WarehouseTransferDetailPage(
              repository: services.warehouseRepository,
              transferNumber: 'TRF-2026-00218',
            ),
        '/dispatch': (_) => DispatchDashboardPage(repository: services.dispatchRepository),
        '/dispatch/load': (_) => DispatchLoadDetailPage(
              repository: services.dispatchRepository,
              dispatchNumber: 'DSP-2026-00417',
            ),
      };
}
