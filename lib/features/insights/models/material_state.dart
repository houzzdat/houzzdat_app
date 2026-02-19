/// Alert for material issues.
class MaterialAlert {
  final String message;
  final String severity; // warning, critical
  final String? materialName;

  const MaterialAlert({
    required this.message,
    required this.severity,
    this.materialName,
  });
}

/// Individual material item in the pipeline.
class MaterialItem {
  final String? id;
  final String name;
  final String? category;
  final String status; // requested, planned, ordered, delivered, installed
  final double quantity;
  final String unit;
  final double? unitPrice;
  final String? vendor;
  final String? urgency;
  final DateTime? deliveryDate;
  final bool isOverdue;

  const MaterialItem({
    this.id,
    required this.name,
    this.category,
    required this.status,
    required this.quantity,
    required this.unit,
    this.unitPrice,
    this.vendor,
    this.urgency,
    this.deliveryDate,
    this.isOverdue = false,
  });
}

/// BOQ variance for a single material.
class BOQVarianceItem {
  final String materialName;
  final String? category;
  final double plannedQty;
  final double consumedQty;
  final String unit;
  final double plannedCost;
  final double actualCost;
  final double qtyVariance;
  final double costVariance;
  final String status; // planned, partially_consumed, fully_consumed, over_consumed

  const BOQVarianceItem({
    required this.materialName,
    this.category,
    required this.plannedQty,
    required this.consumedQty,
    required this.unit,
    required this.plannedCost,
    required this.actualCost,
    required this.qtyVariance,
    required this.costVariance,
    required this.status,
  });
}

/// Complete material pipeline state for a project.
class MaterialPipeline {
  final String? projectId;
  final String projectName;

  // Pipeline counts
  final int requested;
  final int planned;
  final int ordered;
  final int delivered;
  final int installed;

  // BOQ vs Consumption
  final bool hasBOQ;
  final int boqItemCount;
  final int boqItemsFullyConsumed;
  final int boqItemsOverConsumed;
  final double boqBudgetTotal;
  final double boqActualTotal;
  final double boqVariance;
  final double boqUtilization;
  final List<BOQVarianceItem> boqVariances;

  // Urgency
  final int urgentPending;
  final List<MaterialAlert> alerts;

  // Cost
  final double estimatedCost;
  final double actualSpend;

  // Items detail
  final List<MaterialItem> items;

  const MaterialPipeline({
    this.projectId,
    required this.projectName,
    this.requested = 0,
    this.planned = 0,
    this.ordered = 0,
    this.delivered = 0,
    this.installed = 0,
    this.hasBOQ = false,
    this.boqItemCount = 0,
    this.boqItemsFullyConsumed = 0,
    this.boqItemsOverConsumed = 0,
    this.boqBudgetTotal = 0,
    this.boqActualTotal = 0,
    this.boqVariance = 0,
    this.boqUtilization = 0,
    this.boqVariances = const [],
    this.urgentPending = 0,
    this.alerts = const [],
    this.estimatedCost = 0,
    this.actualSpend = 0,
    this.items = const [],
  });
}
