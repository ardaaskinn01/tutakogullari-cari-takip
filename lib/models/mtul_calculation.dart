class MtulCalculation {
  final String id;
  final String customerName;
  final double totalPrice;
  final DateTime createdAt;
  final List<MtulCalculationItem>? items;

  MtulCalculation({
    required this.id,
    required this.customerName,
    required this.totalPrice,
    required this.createdAt,
    this.items,
  });

  factory MtulCalculation.fromJson(Map<String, dynamic> json) {
    var list = json['mtul_calculation_items'] as List<dynamic>?;
    List<MtulCalculationItem>? itemsList;
    if (list != null) {
      itemsList = list.map((i) => MtulCalculationItem.fromJson(i)).toList();
    }

    return MtulCalculation(
      id: json['id'] as String,
      customerName: json['customer_name'] as String,
      totalPrice: (json['total_price'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      items: itemsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_name': customerName,
      'total_price': totalPrice,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class MtulCalculationItem {
  final String id;
  final String calculationId;
  final String componentName;
  final double quantity;
  final double unitPrice;
  final double totalPrice;

  MtulCalculationItem({
    required this.id,
    required this.calculationId,
    required this.componentName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  factory MtulCalculationItem.fromJson(Map<String, dynamic> json) {
    return MtulCalculationItem(
      id: json['id'] as String,
      calculationId: json['calculation_id'] as String,
      componentName: json['component_name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unitPrice: (json['unit_price'] as num).toDouble(),
      totalPrice: (json['total_price'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'calculation_id': calculationId,
      'component_name': componentName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
    };
  }
}
