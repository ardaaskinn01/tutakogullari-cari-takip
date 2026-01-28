class MtulPrice {
  final String id;
  final String category; // 'standard', 'gold_oak', 'anthracite', 'fly_screen'
  final String componentName;
  final double unitPrice;
  final int sortOrder;

  MtulPrice({
    required this.id,
    required this.category,
    required this.componentName,
    required this.unitPrice,
    required this.sortOrder,
  });

  factory MtulPrice.fromJson(Map<String, dynamic> json) {
    return MtulPrice(
      id: json['id'] as String,
      category: json['category'] as String,
      componentName: json['component_name'] as String,
      unitPrice: (json['unit_price'] as num).toDouble(),
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'component_name': componentName,
      'unit_price': unitPrice,
      'sort_order': sortOrder,
    };
  }
}

