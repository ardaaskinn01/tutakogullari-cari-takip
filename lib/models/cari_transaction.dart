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
  final String createdBy; // Ekleyen kullanıcı
  final DateTime createdAt;
  final String? createdByName; // Join ile gelen isim

  CariTransaction({
    required this.id,
    required this.accountId,
    required this.type,
    required this.amount,
    this.paymentMethod,
    this.description,
    required this.createdBy,
    required this.createdAt,
    this.createdByName,
  });

  factory CariTransaction.fromJson(Map<String, dynamic> json) {
    // Handle Supabase join response where profiles might be nested
    String? name;
    if (json['profiles'] != null && json['profiles'] is Map) {
      final profile = json['profiles'];
      name = profile['full_name'] as String? ?? profile['email'] as String?;
    }

    return CariTransaction(
      id: json['id'] as String,
      accountId: json['account_id'] as String,
      type: CariTransactionType.fromString(json['type'] as String),
      amount: (json['amount'] as num).toDouble(),
      paymentMethod: json['payment_method'] != null 
          ? PaymentMethod.fromString(json['payment_method'] as String)
          : null,
      description: json['description'] as String?,
      createdBy: json['created_by'] as String? ?? '', // Fallback for old records
      createdAt: DateTime.parse(json['created_at'] as String),
      createdByName: name,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'account_id': accountId,
      'type': type.value,
      'amount': amount,
      'payment_method': paymentMethod?.value,
      'description': description,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }
  
  bool get isDebt => type == CariTransactionType.debt;
  bool get isCollection => type == CariTransactionType.collection;

  CariTransaction copyWith({
    String? id,
    String? accountId,
    CariTransactionType? type,
    double? amount,
    PaymentMethod? paymentMethod,
    String? description,
    String? createdBy,
    DateTime? createdAt,
    String? createdByName,
  }) {
    return CariTransaction(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      createdByName: createdByName ?? this.createdByName,
    );
  }
}
