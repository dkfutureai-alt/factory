class InventoryItemDetail {
  const InventoryItemDetail({required this.sku,required this.name,required this.category,required this.unit,required this.barcode,required this.onHand,required this.reorderLevel,required this.reserved,required this.standardCost,required this.tracking,required this.location,required this.inboundPending,required this.movements});
  final String sku,name,category,unit,barcode,tracking,location;
  final double onHand,reorderLevel,reserved,standardCost,inboundPending;
  final List<InventoryMovement> movements;
  double get available => (onHand-reserved).clamp(0,double.infinity);
  bool get isLowStock => onHand<=reorderLevel;
}

class InventoryMovement {
  const InventoryMovement({required this.time,required this.type,required this.reference,required this.quantityDelta});
  final String time,type,reference;
  final double quantityDelta;
}

abstract interface class InventoryItemDetailRepository {
  Future<InventoryItemDetail> loadItem(String sku);
}

final class PreviewInventoryItemDetailRepository implements InventoryItemDetailRepository {
  const PreviewInventoryItemDetailRepository();

  @override
  Future<InventoryItemDetail> loadItem(String sku) async {
    return switch (sku) {
      'RM-STEEL-001' => const InventoryItemDetail(
          sku:'RM-STEEL-001',name:'MS Steel Sheet 2mm',category:'Raw Material',unit:'kg',barcode:'890100000001',onHand:1240,reorderLevel:600,reserved:0,standardCost:72.50,tracking:'Batch controlled',location:'RM-WH • RM-A-R03-B02',inboundPending:400,
          movements:[InventoryMovement(time:'14 Oct 12:20',type:'Production issue',reference:'STK-2026-1948',quantityDelta:-160),InventoryMovement(time:'13 Oct 16:40',type:'Purchase receipt',reference:'GRN-2026-00914',quantityDelta:500)]),
      'RM-PIPE-001' => const InventoryItemDetail(
          sku:'RM-PIPE-001',name:'Industrial Pipe 25mm',category:'Raw Material',unit:'pcs',barcode:'890100000002',onHand:182,reorderLevel:200,reserved:0,standardCost:185,tracking:'Batch controlled',location:'RM-WH • RM-B-R01-B04',inboundPending:300,
          movements:[InventoryMovement(time:'14 Oct 10:15',type:'Production issue',reference:'STK-2026-1944',quantityDelta:-40),InventoryMovement(time:'12 Oct 15:10',type:'Purchase receipt',reference:'GRN-2026-00902',quantityDelta:200)]),
      'PK-CARTON-014' => const InventoryItemDetail(
          sku:'PK-CARTON-014',name:'Heavy Duty Carton 14in',category:'Packaging',unit:'pcs',barcode:'890100000004',onHand:860,reorderLevel:300,reserved:0,standardCost:22,tracking:'Standard stock',location:'RM-WH • RM-A-R03-B02',inboundPending:500,
          movements:[InventoryMovement(time:'14 Oct 11:05',type:'Production issue',reference:'STK-2026-1946',quantityDelta:-120),InventoryMovement(time:'11 Oct 10:30',type:'Purchase receipt',reference:'GRN-2026-00888',quantityDelta:600)]),
      'SP-BRG-6204' => const InventoryItemDetail(
          sku:'SP-BRG-6204',name:'Bearing 6204 ZZ',category:'Spare Part',unit:'pcs',barcode:'890100000008',onHand:9,reorderLevel:12,reserved:0,standardCost:265,tracking:'Standard stock',location:'SP-WH • SP-A-R04-B03',inboundPending:20,
          movements:[InventoryMovement(time:'14 Oct 08:45',type:'Maintenance issue',reference:'STK-2026-1941',quantityDelta:-3),InventoryMovement(time:'10 Oct 09:20',type:'Purchase receipt',reference:'GRN-2026-00874',quantityDelta:12)]),
      'FG-VALVE-25' => const InventoryItemDetail(
          sku:'FG-VALVE-25',name:'Valve Assembly 25mm',category:'Finished Good',unit:'pcs',barcode:'890100000011',onHand:420,reorderLevel:150,reserved:0,standardCost:640,tracking:'Batch controlled',location:'FG-WH • FG-A-R01-B08',inboundPending:0,
          movements:[InventoryMovement(time:'14 Oct 13:05',type:'Finished goods receipt',reference:'STK-2026-1950',quantityDelta:300),InventoryMovement(time:'13 Oct 14:20',type:'Sales dispatch',reference:'DSP-2026-00412',quantityDelta:-80)]),
      _ => const InventoryItemDetail(
          sku:'RM-STL-304-02',name:'Stainless Steel Rod 304 • 40mm',category:'Raw Material',unit:'kg',barcode:'8901234500012',onHand:420,reorderLevel:500,reserved:120,standardCost:238,tracking:'Batch controlled',location:'RM-WH • Rack A-03',inboundPending:800,
          movements:[InventoryMovement(time:'14 Oct 13:10',type:'Production issue',reference:'PRD-2026-01038',quantityDelta:-80),InventoryMovement(time:'14 Oct 09:05',type:'Production issue',reference:'PRD-2026-01038',quantityDelta:-120),InventoryMovement(time:'13 Oct 16:40',type:'Purchase receipt',reference:'GRN-2026-00914',quantityDelta:500)]),
    };
  }
}
