class Shift {
  final String id;
  final DateTime openedAt;
  final String status;

  Shift({required this.id, required this.openedAt, required this.status});

  factory Shift.fromJson(Map<String, dynamic> json) {
    return Shift(
      id: json['id'] as String,
      openedAt: DateTime.parse(json['opened_at'] as String),
      status: json['status'] as String,
    );
  }
}

class Profile {
  final String id;
  final String fullName;

  Profile({required this.id, required this.fullName});

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
    );
  }
}

class Order {
  final String id;
  final int queueNumber;
  final String? customerName;
  final double totalAmount;
  final String userId;
  final Profile? profile; // Relasi untuk ambil full_name
  final DateTime createdAt;

  Order({
    required this.id,
    required this.queueNumber,
    this.customerName,
    required this.totalAmount,
    required this.userId,
    this.profile,
    required this.createdAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      queueNumber: json['queue_number'] as int,
      customerName: json['customer_name'] as String?,
      totalAmount: (json['total_amount'] as num).toDouble(),
      userId: json['user_id'] as String,
      profile: json['profiles'] != null ? Profile.fromJson(json['profiles']) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class Expense {
  final String id;
  final String note;
  final double amount;
  final String userId;
  final Profile? profile; // Relasi untuk ambil full_name
  final DateTime createdAt;

  Expense({
    required this.id,
    required this.note,
    required this.amount,
    required this.userId,
    this.profile,
    required this.createdAt,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String,
      note: json['note'] as String,
      amount: (json['amount'] as num).toDouble(),
      userId: json['user_id'] as String,
      profile: json['profiles'] != null ? Profile.fromJson(json['profiles']) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
