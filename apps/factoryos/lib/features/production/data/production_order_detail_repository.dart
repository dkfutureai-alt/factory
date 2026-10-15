class ProductionOrderDetail {
  const ProductionOrderDetail({required this.number,required this.product,required this.line,required this.status,required this.planned,required this.completed,required this.startedAt,required this.dueAt,required this.batchNumber,required this.qcStatus,required this.rejected,required this.materials,required this.timeline});
  final String number, product, line, status, startedAt, dueAt, batchNumber, qcStatus;
  final int planned, completed, rejected;
  final List<ProductionMaterialRequirement> materials;
  final List<ProductionTimelineEvent> timeline;
  double get achievement => planned == 0 ? 0 : completed / planned;
  bool get canAttemptCompletion => status != 'Completed' && qcStatus == 'Pass';
}

class ProductionMaterialRequirement {
  const ProductionMaterialRequirement({required this.sku,required this.name,required this.required,required this.available,required this.unit});
  final String sku, name, unit;
  final double required, available;
  double get shortage => (required - available).clamp(0, double.infinity);
}

class ProductionTimelineEvent {
  const ProductionTimelineEvent({required this.title,required this.detail,required this.time,required this.isWarning});
  final String title, detail, time;
  final bool isWarning;
}

abstract interface class ProductionOrderDetailRepository {
  bool get supportsCompletion;
  Future<ProductionOrderDetail> loadOrder(String number);
  Future<ProductionOrderDetail> completeActiveBatch(String number);
}

final class PreviewProductionOrderDetailRepository implements ProductionOrderDetailRepository {
  const PreviewProductionOrderDetailRepository();

  @override
  bool get supportsCompletion => false;

  @override
  Future<ProductionOrderDetail> loadOrder(String number) async => const ProductionOrderDetail(
    number:'PRD-2026-01038', product:'Industrial Component X', line:'LINE-02', status:'In Production', planned:500, completed:420,
    startedAt:'14 Oct • 09:20', dueAt:'14 Oct • 17:00', batchNumber:'PB-141026-A06', qcStatus:'QC Hold', rejected:8,
    materials:[
      ProductionMaterialRequirement(sku:'RM-STL-304-02',name:'Stainless Steel Rod 304 • 40mm',required:492,available:420,unit:'kg'),
      ProductionMaterialRequirement(sku:'RM-BRG-6204',name:'Bearing 6204 ZZ',required:500,available:820,unit:'nos'),
    ],
    timeline:[
      ProductionTimelineEvent(title:'Order started',detail:'Ravi Patil',time:'09:20',isWarning:false),
      ProductionTimelineEvent(title:'Material issued',detail:'STK-2026-1942',time:'10:05',isWarning:false),
      ProductionTimelineEvent(title:'QC hold raised',detail:'QC-2026-00418',time:'13:42',isWarning:true),
    ],
  );

  @override
  Future<ProductionOrderDetail> completeActiveBatch(String number) async {
    throw UnsupportedError('Production completion is unavailable in preview mode.');
  }
}
