import 'transaction.dart'; // PaymentMethod enum'ı buradan geliyor

enum CariTransactionType {
  debt('debt', 'Alacak (Borç)'),
  collection('collection', 'Tahsilat');

  final String value;
  final String displayName;

  const CariTransactionType(this.value, this.displayName);

  static CariTransactionType fromString(String value) {
    return CariTransactionType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => CariTransactionType.debt,
    );
  }
}

class CariTransaction {
  final String id;
  final String accountId;
  final CariTransactionType type;
  final double amount;
  final PaymentMethod? paymentMethod; // Sadece tahsilat ise dolu
  final String? description;
  final DateTime createdAt;

  CariTransaction({
    required this.id,
    required this.accountId,
    required this.type,
    required this.amount,
    this.paymentMethod,
    this.description,
    required this.createdAt,
  });

  factory CariTransaction.fromJson(Map<String, dynamic> json) {
    return CariTransaction(
      id: json['id'] as String,
      accountId: json['account_id'] as String,
      type: CariTransactionType.fromString(json['type'] as String),
      amount: (json['amount'] as num).toDouble(),
      paymentMethod: json['payment_method'] != null 
          ? PaymentMethod.fromString(json['payment_method'] as String)
          : null,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_id': accountId,
      'type': type.value,
      'amount': amount,
      'payment_method': paymentMethod?.value,
      'description': description,
      'created_at': createdAt.toIso8601String(),
    };
  }
  
  bool get isDebt => type == CariTransactionType.debt;
  bool get isCollection => type == CariTransactionType.collection;
}
