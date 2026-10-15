import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/dispatch/data/dispatch_repository.dart';
import '../../features/dispatch/data/supabase_dispatch_repository.dart';
import '../../features/warehouse/data/supabase_warehouse_repository.dart';
import '../../features/warehouse/data/warehouse_repository.dart';
import 'backend_config.dart';

class FactoryOsServices {
  const FactoryOsServices({
    required this.config,
    required this.authRepository,
    required this.warehouseRepository,
    required this.dispatchRepository,
  });

  factory FactoryOsServices.preview([FactoryOsBackendConfig? config]) {
    return FactoryOsServices(
      config: config ?? const FactoryOsBackendConfig(mode: FactoryOsBackendMode.preview),
      authRepository: const PreviewAuthRepository(),
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
      warehouseRepository: SupabaseWarehouseRepository(client),
      dispatchRepository: SupabaseDispatchRepository(client),
    );
  }

  final FactoryOsBackendConfig config;
  final AuthRepository authRepository;
  final WarehouseRepository warehouseRepository;
  final DispatchRepository dispatchRepository;
}
