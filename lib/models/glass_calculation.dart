class GlassCalculation {
  final String id;
  final String customerName;
  final double width;
  final double height;
  final double m2;
  final int quantity;
  final double totalM2;
  final double unitPrice;
  final double totalPrice;
  final DateTime createdAt;

  GlassCalculation({
    required this.id,
    required this.customerName,
    required this.width,
    required this.height,
    required this.m2,
    required this.quantity,
    required this.totalM2,
    required this.unitPrice,
    required this.totalPrice,
    required this.createdAt,
  });

  factory GlassCalculation.fromJson(Map<String, dynamic> json) {
    return GlassCalculation(
      id: json['id'] as String,
      customerName: json['customer_name'] as String,
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      m2: (json['m2'] as num).toDouble(),
      quantity: (json['quantity'] as num).toInt(),
      totalM2: (json['total_m2'] as num).toDouble(),
      unitPrice: (json['unit_price'] as num).toDouble(),
      totalPrice: (json['total_price'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_name': customerName,
      'width': width,
      'height': height,
      'm2': m2,
      'quantity': quantity,
      'total_m2': totalM2,
      'unit_price': unitPrice,
      'total_price': totalPrice,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
