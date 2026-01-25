class UserProfile {
  final String id;
  final String email;
  final String? fullName; // Yeni eklenen alan
  final String? password; // Plain text password for easy viewing
  final String role;
  final DateTime? createdAt;

  UserProfile({
    required this.id,
    required this.email,
    this.fullName,
    this.password,
    required this.role,
    this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String?,
      password: json['password'] as String?,
      role: json['role'] as String? ?? 'user',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'password': password,
      'role': role,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  bool get isAdmin => role == 'admin';
  bool get isUser => role == 'user';
  
  // Görüntülenecek isim: Varsa Ad Soyad, yoksa E-posta başı
  String get displayName => fullName ?? email.split('@')[0];

  UserProfile copyWith({
    String? id,
    String? email,
    String? fullName,
    String? password,
    String? role,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      password: password ?? this.password,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
