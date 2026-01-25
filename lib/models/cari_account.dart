class CariAccount {
  final String id;
  final String fullName;
  final String? phone;
  final double currentBalance;
  final DateTime createdAt;

  CariAccount({
    required this.id,
    required this.fullName,
    this.phone,
    required this.currentBalance,
    required this.createdAt,
  });

  factory CariAccount.fromJson(Map<String, dynamic> json) {
    return CariAccount(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      phone: json['phone'] as String?,
      currentBalance: (json['current_balance'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'phone': phone,
      'current_balance': currentBalance,
      'created_at': createdAt.toIso8601String(),
    };
  }

  CariAccount copyWith({
    String? id,
    String? fullName,
    String? phone,
    double? currentBalance,
    DateTime? createdAt,
  }) {
    return CariAccount(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      currentBalance: currentBalance ?? this.currentBalance,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
