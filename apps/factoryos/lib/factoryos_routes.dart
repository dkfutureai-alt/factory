import 'package:flutter/material.dart';
import 'factoryos_routes_operations.dart';
import 'factoryos_routes_people.dart';
import 'factoryos_routes_fleet.dart';

class FactoryOsRoutes {
  static final Map<String, WidgetBuilder> routes = {
    ...FactoryOsOperationsRoutes.routes,
    ...FactoryOsPeopleRoutes.routes,
    ...FactoryOsFleetRoutes.routes,
  };
}
