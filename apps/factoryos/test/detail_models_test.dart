import 'package:factoryos/features/inventory/data/inventory_item_detail_repository.dart';
import 'package:factoryos/features/production/data/production_order_detail_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main(){
  test('production material shortage never goes negative',(){
    const short=ProductionMaterialRequirement(sku:'A',name:'A',required:100,available:72,unit:'kg');
    const ready=ProductionMaterialRequirement(sku:'B',name:'B',required:50,available:80,unit:'nos');
    expect(short.shortage,28);expect(ready.shortage,0);
  });
  test('inventory detail derives available and low stock',(){
    const item=InventoryItemDetail(sku:'A',name:'A',category:'Raw',unit:'kg',barcode:'1',onHand:420,reorderLevel:500,reserved:120,standardCost:10,tracking:'Batch',location:'A-1',inboundPending:0,movements:[]);
    expect(item.available,300);expect(item.isLowStock,isTrue);
  });
}
