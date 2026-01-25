enum TransactionType {
  income('income', 'Gelir'),
  expense('expense', 'Gider');

  final String value;
  final String displayName;

  const TransactionType(this.value, this.displayName);

  static TransactionType fromString(String value) {
    return TransactionType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => TransactionType.income,
    );
  }
}

enum PaymentMethod {
  cash('cash', 'Nakit'),
  creditCard('credit_card', 'Kredi Kartı'),
  checkNote('check_note', 'Çek / Senet');

  final String value;
  final String displayName;

  const PaymentMethod(this.value, this.displayName);

  static PaymentMethod fromString(String value) {
    return PaymentMethod.values.firstWhere(
      (type) => type.value == value,
      orElse: () => PaymentMethod.cash,
    );
  }
}

class Transaction {
  final String? id;
  final TransactionType type;
  final PaymentMethod paymentMethod;
  final double amount;
  final String description;
  final String createdBy;
  final DateTime createdAt;
  final String? createdByName;

  Transaction({
    this.id,
    required this.type,
    required this.paymentMethod,
    required this.amount,
    required this.description,
    required this.createdBy,
    required this.createdAt,
    this.createdByName,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    // Handle Supabase join response where profiles might be nested
    String? name;
    if (json['profiles'] != null && json['profiles'] is Map) {
      final profile = json['profiles'];
      name = profile['full_name'] as String? ?? profile['email'] as String?;
    } else {
      name = json['created_by_name'] as String?; // Fallback
    }

    return Transaction(
      id: json['id'] as String?,
      type: TransactionType.fromString(json['type'] as String),
      paymentMethod: PaymentMethod.fromString(json['payment_method'] as String? ?? 'cash'),
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      createdByName: name,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'type': type.value,
      'payment_method': paymentMethod.value,
      'amount': amount,
      'description': description,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isIncome => type == TransactionType.income;
  bool get isExpense => type == TransactionType.expense;

  Transaction copyWith({
    String? id,
    TransactionType? type,
    PaymentMethod? paymentMethod,
    double? amount,
    String? description,
    String? createdBy,
    DateTime? createdAt,
    String? createdByName,
  }) {
    return Transaction(
      id: id ?? this.id,
      type: type ?? this.type,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      createdByName: createdByName ?? this.createdByName,
    );
  }
}
