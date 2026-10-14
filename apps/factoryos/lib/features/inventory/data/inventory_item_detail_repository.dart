class InventoryItemDetail {
  const InventoryItemDetail({required this.sku,required this.name,required this.category,required this.unit,required this.barcode,required this.onHand,required this.reorderLevel,required this.reserved,required this.standardCost,required this.tracking,required this.location,required this.inboundPending,required this.movements});
  final String sku,name,category,unit,barcode,tracking,location;
  final double onHand,reorderLevel,reserved,standardCost,inboundPending;
  final List<InventoryMovement> movements;
  double get available => (onHand-reserved).clamp(0,double.infinity);
  bool get isLowStock => onHand<=reorderLevel;
}
class InventoryMovement{const InventoryMovement({required this.time,required this.type,required this.reference,required this.quantityDelta});final String time,type,reference;final double quantityDelta;}
abstract interface class InventoryItemDetailRepository{Future<InventoryItemDetail> loadItem(String sku);}
final class PreviewInventoryItemDetailRepository implements InventoryItemDetailRepository{
  const PreviewInventoryItemDetailRepository();
  @override Future<InventoryItemDetail> loadItem(String sku) async=>const InventoryItemDetail(
    sku:'RM-STL-304-02',name:'Stainless Steel Rod 304 • 40mm',category:'Raw Material',unit:'kg',barcode:'8901234500012',onHand:420,reorderLevel:500,reserved:120,standardCost:238,tracking:'Batch controlled',location:'RM-WH • Rack A-03',inboundPending:800,
    movements:[InventoryMovement(time:'14 Oct 13:10',type:'Production issue',reference:'PRD-2026-01038',quantityDelta:-80),InventoryMovement(time:'14 Oct 09:05',type:'Production issue',reference:'PRD-2026-01038',quantityDelta:-120),InventoryMovement(time:'13 Oct 16:40',type:'Purchase receipt',reference:'GRN-2026-00914',quantityDelta:500)]);
}
