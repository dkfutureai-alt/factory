import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/dispatch/data/dispatch_repository.dart';
import '../../features/dispatch/data/supabase_dispatch_repository.dart';
import '../../features/inventory/data/inventory_item_detail_repository.dart';
import '../../features/inventory/data/inventory_repository.dart';
import '../../features/inventory/data/supabase_inventory_item_detail_repository.dart';
import '../../features/inventory/data/supabase_inventory_repository.dart';
import '../../features/production/data/production_order_detail_repository.dart';
import '../../features/production/data/production_repository.dart';
import '../../features/production/data/supabase_production_order_detail_repository.dart';
import '../../features/production/data/supabase_production_repository.dart';
import '../../features/warehouse/data/supabase_warehouse_repository.dart';
import '../../features/warehouse/data/warehouse_repository.dart';
import 'backend_config.dart';

class FactoryOsServices {
  const FactoryOsServices({
    required this.config,
    required this.authRepository,
    required this.inventoryRepository,
    required this.inventoryItemDetailRepository,
    required this.productionRepository,
    required this.productionOrderDetailRepository,
    required this.warehouseRepository,
    required this.dispatchRepository,
  });

  factory FactoryOsServices.preview([FactoryOsBackendConfig? config]) {
    return FactoryOsServices(
      config: config ?? const FactoryOsBackendConfig(mode: FactoryOsBackendMode.preview),
      authRepository: const PreviewAuthRepository(),
      inventoryRepository: const PreviewInventoryRepository(),
      inventoryItemDetailRepository: const PreviewInventoryItemDetailRepository(),
      productionRepository: const PreviewProductionRepository(),
      productionOrderDetailRepository: const PreviewProductionOrderDetailRepository(),
      warehouseRepository: const PreviewWarehouseRepository(),
      dispatchRepository: const PreviewDispatchRepository(),
    );
  }

  factory FactoryOsServices.supabase({
    required FactoryOsBackendConfig config,
    required SupabaseClient client,
  }) {
    return FactoryOsServices(
      config: config,
      authRepository: SupabaseAuthRepository(client),
      inventoryRepository: SupabaseInventoryRepository(client),
      inventoryItemDetailRepository: SupabaseInventoryItemDetailRepository(client),
      productionRepository: SupabaseProductionRepository(client),
      productionOrderDetailRepository: SupabaseProductionOrderDetailRepository(client),
      warehouseRepository: SupabaseWarehouseRepository(client),
      dispatchRepository: SupabaseDispatchRepository(client),
    );
  }

  final FactoryOsBackendConfig config;
  final AuthRepository authRepository;
  final InventoryRepository inventoryRepository;
  final InventoryItemDetailRepository inventoryItemDetailRepository;
  final ProductionRepository productionRepository;
  final ProductionOrderDetailRepository productionOrderDetailRepository;
  final WarehouseRepository warehouseRepository;
  final DispatchRepository dispatchRepository;
}
