import 'package:flutter/material.dart';

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
        '/inventory': (_) => InventoryDashboardPage(
              repository: services.inventoryRepository,
              detailRepository: services.inventoryItemDetailRepository,
              stockEntryRepository: services.inventoryStockEntryRepository,
            ),
        '/inventory/item': (_) => InventoryItemDetailPage(
              repository: services.inventoryItemDetailRepository,
              sku: 'RM-STEEL-001',
            ),
        '/inventory/stock-entry': (_) => InventoryStockEntryPage(
              repository: services.inventoryStockEntryRepository,
            ),
        '/production': (_) => ProductionDashboardPage(
              repository: services.productionRepository,
              detailRepository: services.productionOrderDetailRepository,
            ),
        '/production/order': (_) => ProductionOrderDetailPage(
              repository: services.productionOrderDetailRepository,
              orderNumber: 'PRD-2026-01038',
            ),
        '/purchase': (_) => PurchaseDashboardPage(
              repository: services.purchaseRepository,
              workflowRepository: services.purchaseOrderWorkflowRepository,
              receiptRepository: services.purchaseReceiptRepository,
            ),
        '/purchase/order': (_) => PurchaseOrderDetailPage(
              repository: services.purchaseRepository,
              orderNumber: 'PO-2026-00481',
              workflowRepository: services.purchaseOrderWorkflowRepository,
              receiptRepository: services.purchaseReceiptRepository,
            ),
        '/purchase/create': (_) => PurchaseOrderEditorPage(
              repository: services.purchaseOrderWorkflowRepository,
            ),
        '/purchase/approval': (_) => PurchaseOrderApprovalPage(
              repository: services.purchaseOrderWorkflowRepository,
              orderNumber: 'PO-2026-00482',
            ),
        '/purchase/grn': (_) => PurchaseGoodsReceiptPage(
              repository: services.purchaseReceiptRepository,
              orderNumber: 'PO-2026-00481',
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