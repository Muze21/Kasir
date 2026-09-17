import 'package:flutter/material.dart';

class Shift {
  final String id;
  final DateTime openedAt;
  final String status;
  final String? openedBy;
  final String? closedBy;
  final DateTime? closedAt;
  final Profile? opener;
  final Profile? closer;

  Shift({
    required this.id,
    required this.openedAt,
    required this.status,
    this.openedBy,
    this.closedBy,
    this.closedAt,
    this.opener,
    this.closer,
  });

  bool get isOpen => status == 'open';

  factory Shift.fromJson(Map<String, dynamic> json) {
    return Shift(
      id: json['id'] as String,
      openedAt: DateTime.parse(json['opened_at'] as String).toLocal(),
      status: json['status'] as String,
      openedBy: json['opened_by'] as String?,
      closedBy: json['closed_by'] as String?,
      closedAt: json['closed_at'] != null ? DateTime.parse(json['closed_at'] as String).toLocal() : null,
      opener: json['opener'] != null ? Profile.fromJson(json['opener']) : null,
      closer: json['closer'] != null ? Profile.fromJson(json['closer']) : null,
    );
  }
}

class ShiftStats {
  final int orderCount;
  final double omzet;
  final double expenses;
  final double bersih;

  ShiftStats({required this.orderCount, required this.omzet, required this.expenses})
      : bersih = omzet - expenses;

  factory ShiftStats.fromData({required int orderCount, required List<dynamic> orders, required List<dynamic> expenses}) {
    var omzet = 0.0;
    var activeOrdersCount = 0;
    for (final o in orders) {
      final status = (o['status'] as String?) ?? 'completed';
      if (status == 'voided') continue;
      omzet += (o['total_amount'] as num).toDouble();
      activeOrdersCount++;
    }
    var exp = 0.0;
    for (final e in expenses) {
      exp += (e['amount'] as num).toDouble();
    }
    return ShiftStats(orderCount: activeOrdersCount, omzet: omzet, expenses: exp);
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

class OrderItem {
  final String id;
  final String orderId;
  final String itemName;
  final int qty;
  final double price;
  final double subtotal;

  OrderItem({
    required this.id,
    required this.orderId,
    required this.itemName,
    required this.qty,
    required this.price,
    required this.subtotal,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      itemName: json['item_name'] as String,
      qty: json['qty'] as int,
      price: (json['price'] as num).toDouble(),
      subtotal: (json['subtotal'] as num).toDouble(),
    );
  }
}

class Order {
  final String id;
  final int queueNumber;
  final String? customerName;
  final double totalAmount;
  final String paymentMethod; // 'cash' or 'qris'
  final String userId;
  final String status; // 'completed' or 'voided'
  final String? voidReason;
  final Profile? profile;
  final List<OrderItem> items;
  final DateTime createdAt;

  bool get isVoided => status == 'voided';

  Order({
    required this.id,
    required this.queueNumber,
    this.customerName,
    required this.totalAmount,
    required this.paymentMethod,
    required this.userId,
    this.status = 'completed',
    this.voidReason,
    this.profile,
    this.items = const [],
    required this.createdAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    List<OrderItem> itemsList = [];
    if (json['order_items'] != null && json['order_items'] is List) {
      itemsList = (json['order_items'] as List)
          .map((item) => OrderItem.fromJson(item))
          .toList();
    }

    return Order(
      id: json['id'] as String,
      queueNumber: (json['queue_number'] as num?)?.toInt() ?? 0,
      customerName: json['customer_name'] as String?,
      totalAmount: (json['total_amount'] as num).toDouble(),
      paymentMethod: (json['payment_method'] as String?) ?? 'cash',
      userId: json['user_id'] as String,
      status: (json['status'] as String?) ?? 'completed',
      voidReason: json['void_reason'] as String?,
      profile: json['profiles'] != null ? Profile.fromJson(json['profiles']) : null,
      items: itemsList,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}

class Expense {
  final String id;
  final String note;
  final double amount;
  final String category; // 'Bahan Baku' | 'Operasional' | 'Transport' | 'Lainnya'
  final String userId;
  final Profile? profile;
  final DateTime createdAt;

  Expense({
    required this.id,
    required this.note,
    required this.amount,
    this.category = 'Operasional',
    required this.userId,
    this.profile,
    required this.createdAt,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String,
      note: json['note'] as String,
      amount: (json['amount'] as num).toDouble(),
      category: (json['category'] as String?) ?? 'Operasional',
      userId: json['user_id'] as String,
      profile: json['profiles'] != null ? Profile.fromJson(json['profiles']) : null,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}

// Kategori pengeluaran tetap (satu-satunya sumber kebenaran biar konsisten di semua UI)
class ExpenseCategories {
  static const List<String> all = ['Bahan Baku', 'Operasional', 'Transport', 'Lainnya'];

  static const Map<String, IconData> icons = {
    'Bahan Baku': Icons.inventory_2_outlined,
    'Operasional': Icons.handyman_outlined,
    'Transport': Icons.local_shipping_outlined,
    'Lainnya': Icons.more_horiz_outlined,
  };

  static Color background(String category) {
    switch (category) {
      case 'Bahan Baku':
        return const Color(0xFFEDF3EC);
      case 'Operasional':
        return const Color(0xFFE1F3FE);
      case 'Transport':
        return const Color(0xFFFBF3DB);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  static Color textColor(String category) {
    switch (category) {
      case 'Bahan Baku':
        return const Color(0xFF346538);
      case 'Operasional':
        return const Color(0xFF1F6C9F);
      case 'Transport':
        return const Color(0xFF956400);
      default:
        return const Color(0xFF64748B);
    }
  }
}

class UserContribution {
  final String userId;
  final String userName;
  final int orderCount;
  final double omzet;
  final double expenses;

  double get bersih => omzet - expenses;

  UserContribution({
    required this.userId,
    required this.userName,
    required this.orderCount,
    required this.omzet,
    required this.expenses,
  });
}

class ShiftReportData {
  final Shift shift;
  final int totalOrders;
  final double totalOmzet;
  final double totalCash;
  final double totalQris;
  final double totalExpenses;
  final double bersih;
  final List<UserContribution> userContributions;
  final List<Order> orders;
  final List<Expense> expenses;

  ShiftReportData({
    required this.shift,
    required this.totalOrders,
    required this.totalOmzet,
    required this.totalCash,
    required this.totalQris,
    required this.totalExpenses,
    required this.bersih,
    required this.userContributions,
    required this.orders,
    required this.expenses,
  });
}

class DailySummary {
  final DateTime date;
  final String dayLabel;
  final double omzet;
  final double expenses;
  final int orderCount;

  double get bersih => omzet - expenses;

  DailySummary({
    required this.date,
    required this.dayLabel,
    required this.omzet,
    required this.expenses,
    required this.orderCount,
  });
}

class TopItemSummary {
  final String itemName;
  final int totalQty;
  final double totalRevenue;

  TopItemSummary({
    required this.itemName,
    required this.totalQty,
    required this.totalRevenue,
  });
}

class PeriodicReportData {
  final DateTime startDate;
  final DateTime endDate;
  final double totalOmzet;
  final double totalExpenses;
  final double bersih;
  final int totalOrders;
  final double totalCash;
  final double totalQris;
  final int cashOrderCount;
  final int qrisOrderCount;
  final List<DailySummary> dailySummaries;
  final List<TopItemSummary> topItems;
  final List<Expense> expenses;
  final List<Order> orders;

  PeriodicReportData({
    required this.startDate,
    required this.endDate,
    required this.totalOmzet,
    required this.totalExpenses,
    required this.bersih,
    required this.totalOrders,
    required this.totalCash,
    required this.totalQris,
    required this.cashOrderCount,
    required this.qrisOrderCount,
    required this.dailySummaries,
    required this.topItems,
    required this.expenses,
    required this.orders,
  });
}

class Product {
  final String id;
  final String name;
  final double price;
  final String category;
  final bool isAvailable;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    this.isAvailable = true,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      category: (json['category'] ?? 'Makanan').toString(),
      isAvailable: json['is_available'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'price': price,
      'category': category,
      'is_available': isAvailable,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'category': category,
    };
  }
}

